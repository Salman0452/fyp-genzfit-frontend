"""
Storage Service
Handles 3D model storage, thumbnail generation, and Firestore operations
"""

import io
import base64
import hashlib
from typing import Dict, Optional
import logging
import trimesh
import numpy as np
from PIL import Image
import firebase_admin
from firebase_admin import firestore, storage
from datetime import datetime

logger = logging.getLogger(__name__)


class StorageService:
    """Manages avatar storage and database operations"""
    
    def __init__(self):
        """Initialize storage service"""
        self.db = firestore.client()
        self.bucket = storage.bucket()
        
    async def upload_avatar_model(
        self,
        mesh: trimesh.Trimesh,
        user_id: str,
        version: str = "latest"
    ) -> str:
        """
        Upload 3D model to Firebase Storage
        
        Args:
            mesh: Trimesh object to upload
            user_id: User ID
            version: Version identifier (e.g., "initial", "day_30")
            
        Returns:
            Public URL of uploaded model
        """
        try:
            # Export mesh to GLB format (binary glTF)
            glb_data = self._export_to_glb(mesh)
            
            # Generate filename
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            filename = f"avatars/{user_id}/{version}_{timestamp}.glb"
            
            # Upload to Firebase Storage
            blob = self.bucket.blob(filename)
            blob.upload_from_string(
                glb_data,
                content_type='model/gltf-binary'
            )
            
            # Make public
            blob.make_public()
            
            url = blob.public_url
            logger.info(f"Model uploaded: {url}")
            
            return url
            
        except Exception as e:
            logger.error(f"Error uploading model: {str(e)}")
            raise
    
    def _export_to_glb(self, mesh) -> bytes:
        """Export trimesh.Trimesh or trimesh.Scene to GLB binary format."""
        if isinstance(mesh, trimesh.Scene):
            export_data = mesh.export(file_type='glb')
        elif isinstance(mesh, trimesh.Trimesh):
            export_data = mesh.export(file_type='glb')
        else:
            # Fallback: wrap in scene and export
            scene = trimesh.Scene()
            scene.add_geometry(mesh)
            export_data = scene.export(file_type='glb')

        if isinstance(export_data, str):
            return export_data.encode('utf-8')
        return bytes(export_data)
    
    async def generate_thumbnail(
        self,
        mesh: trimesh.Trimesh,
        user_id: str,
        size: tuple = (512, 512)
    ) -> str:
        """
        Generate thumbnail image from 3D model
        
        Args:
            mesh: Trimesh object
            user_id: User ID
            size: Thumbnail size (width, height)
            
        Returns:
            Public URL of thumbnail
        """
        try:
            # Create a simple front-view orthographic projection
            from PIL import Image, ImageDraw

            # Resolve to a single Trimesh for thumbnail (use first geometry if Scene)
            if isinstance(mesh, trimesh.Scene):
                geoms = list(mesh.geometry.values())
                draw_mesh = geoms[0] if geoms else None
            else:
                draw_mesh = mesh

            img = Image.new('RGB', size, color=(230, 235, 245))
            draw = ImageDraw.Draw(img)

            if draw_mesh is not None:
                verts  = draw_mesh.vertices
                bounds = verts.max(axis=0) - verts.min(axis=0)
                span   = max(bounds[0], bounds[1])
                if span < 1e-6:
                    span = 1.0

                scale    = size[0] * 0.75 / span
                cx, cy   = size[0] // 2, size[1] // 2
                v_min    = verts.min(axis=0)

                # Front-view: X → screen-X,  Y → screen-Y (flip)
                sx = ((verts[:, 0] - v_min[0]) * scale + cx - bounds[0] * scale / 2).astype(int)
                sy = (size[1] - (verts[:, 1] - v_min[1]) * scale
                      - cy + bounds[1] * scale / 2).astype(int)

                for face in draw_mesh.faces[:500]:
                    pts = [(int(sx[v]), int(sy[v])) for v in face]
                    draw.polygon(pts, fill=(180, 140, 110), outline=(100, 80, 60))

            # Save to bytes
            img_bytes = io.BytesIO()
            img.save(img_bytes, format='PNG')
            png_data = img_bytes.getvalue()
            
            # Upload thumbnail
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            filename = f"avatars/{user_id}/thumbnails/{timestamp}.png"
            
            blob = self.bucket.blob(filename)
            blob.upload_from_string(
                png_data,
                content_type='image/png'
            )
            blob.make_public()
            
            url = blob.public_url
            logger.info(f"Thumbnail generated: {url}")
            
            return url
            
        except Exception as e:
            logger.error(f"Error generating thumbnail: {str(e)}")
            # Return placeholder URL
            return "https://via.placeholder.com/512"
    
    async def save_avatar_metadata(
        self,
        user_id: str,
        model_url: str,
        thumbnail_url: str,
        measurements: Dict
    ):
        """Save avatar metadata to Firestore"""
        try:
            doc_ref = self.db.collection('avatars').document(user_id)
            
            data = {
                'userId': user_id,
                'currentModelUrl': model_url,
                'thumbnailUrl': thumbnail_url,
                'baselineMeasurements': measurements,
                'createdAt': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP,
                'version': 1
            }
            
            doc_ref.set(data, merge=True)
            logger.info(f"Avatar metadata saved for user: {user_id}")
            
        except Exception as e:
            logger.error(f"Error saving metadata: {str(e)}")
            raise
    
    async def save_physique_history(
        self,
        user_id: str,
        model_url: str,
        body_changes: Dict,
        day: int
    ):
        """Save physique progress to history"""
        try:
            doc_ref = self.db.collection('avatars').document(user_id)
            
            history_entry = {
                'day': day,
                'model_url': model_url,
                'weight': body_changes.get('new_weight', 0),
                'body_fat_percentage': body_changes.get('body_fat_percentage', 0),
                'muscle_gain': body_changes.get('muscle_gain', 0),
                'fat_loss': body_changes.get('fat_loss', 0),
                'timestamp': firestore.SERVER_TIMESTAMP
            }
            
            doc_ref.update({
                'physiqueHistory': firestore.ArrayUnion([history_entry]),
                'updatedAt': firestore.SERVER_TIMESTAMP
            })
            
            logger.info(f"History saved for user {user_id}, day {day}")
            
        except Exception as e:
            logger.error(f"Error saving history: {str(e)}")
            raise
    
    async def get_avatar_data(self, user_id: str) -> Optional[Dict]:
        """Get avatar data from Firestore"""
        try:
            doc_ref = self.db.collection('avatars').document(user_id)
            doc = doc_ref.get()
            
            if doc.exists:
                data = doc.to_dict()
                
                # If mesh_data doesn't exist, download from URL
                if 'mesh_data' not in data and 'currentModelUrl' in data:
                    mesh = self._download_mesh(data['currentModelUrl'])
                    data['mesh_data'] = mesh
                
                return data
            else:
                return None
                
        except Exception as e:
            logger.error(f"Error getting avatar data: {str(e)}")
            return None
    
    def _download_mesh(self, url: str) -> trimesh.Trimesh:
        """Download mesh from URL"""
        import requests
        
        response = requests.get(url)
        mesh = trimesh.load(
            io.BytesIO(response.content),
            file_type='glb'
        )
        
        return mesh
    
    async def get_physique_history(self, user_id: str) -> list:
        """Get physique progress history"""
        try:
            doc_ref = self.db.collection('avatars').document(user_id)
            doc = doc_ref.get()
            
            if doc.exists:
                data = doc.to_dict()
                history = data.get('physiqueHistory', [])
                
                # Sort by day
                history.sort(key=lambda x: x.get('day', 0))
                
                return history
            else:
                return []
                
        except Exception as e:
            logger.error(f"Error getting history: {str(e)}")
            return []
    
    async def delete_avatar(self, user_id: str):
        """Delete avatar and all associated data"""
        try:
            # Delete Firestore document
            doc_ref = self.db.collection('avatars').document(user_id)
            doc_ref.delete()
            
            # Delete all files in storage
            prefix = f"avatars/{user_id}/"
            blobs = self.bucket.list_blobs(prefix=prefix)
            
            for blob in blobs:
                blob.delete()
            
            logger.info(f"Avatar deleted for user: {user_id}")
            
        except Exception as e:
            logger.error(f"Error deleting avatar: {str(e)}")
            raise
    
    async def compare_avatar_states(
        self,
        user_id: str,
        day1: int,
        day2: int
    ) -> Dict:
        """Compare two avatar states"""
        try:
            history = await self.get_physique_history(user_id)
            
            state1 = next((h for h in history if h['day'] == day1), None)
            state2 = next((h for h in history if h['day'] == day2), None)
            
            if not state1 or not state2:
                raise ValueError("Invalid day numbers")
            
            comparison = {
                "day1": state1,
                "day2": state2,
                "differences": {
                    "weight_change": state2['weight'] - state1['weight'],
                    "bf_change": state2['body_fat_percentage'] - state1['body_fat_percentage'],
                    "days_between": day2 - day1
                }
            }
            
            return comparison
            
        except Exception as e:
            logger.error(f"Error comparing avatars: {str(e)}")
            raise


# Cloudinary integration (alternative to Firebase Storage)
class CloudinaryStorage(StorageService):
    """Alternative storage using Cloudinary"""
    
    def __init__(self, cloud_name: str, api_key: str, api_secret: str):
        super().__init__()
        import cloudinary
        import cloudinary.uploader
        
        cloudinary.config(
            cloud_name=cloud_name,
            api_key=api_key,
            api_secret=api_secret
        )
        
        self.cloudinary = cloudinary
    
    async def upload_avatar_model(
        self,
        mesh: trimesh.Trimesh,
        user_id: str,
        version: str = "latest"
    ) -> str:
        """Upload to Cloudinary"""
        glb_data = self._export_to_glb(mesh)
        
        result = self.cloudinary.uploader.upload(
            glb_data,
            resource_type="raw",
            folder=f"avatars/{user_id}",
            public_id=f"{version}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"
        )
        
        return result['secure_url']
