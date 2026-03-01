"""
Firebase Admin SDK initialization
"""

import os
import json
import firebase_admin
from firebase_admin import credentials
import logging

logger = logging.getLogger(__name__)


def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        # Check if already initialized
        if firebase_admin._apps:
            logger.info("Firebase already initialized")
            return
        
        # Get credentials from environment or file
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        cred_json = os.getenv('FIREBASE_CREDENTIALS_JSON')
        
        if cred_json:
            # Parse JSON from environment variable
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
        elif cred_path and os.path.exists(cred_path):
            # Load from file
            cred = credentials.Certificate(cred_path)
        else:
            # Use application default credentials (for Cloud Run)
            cred = credentials.ApplicationDefault()
        
        # Get storage bucket name
        storage_bucket = os.getenv('FIREBASE_STORAGE_BUCKET')
        
        # Initialize app
        firebase_admin.initialize_app(cred, {
            'storageBucket': storage_bucket
        })
        
        logger.info("Firebase initialized successfully")
        
    except Exception as e:
        logger.error(f"Error initializing Firebase: {str(e)}")
        raise


def get_firestore_client():
    """Get Firestore client"""
    from firebase_admin import firestore
    return firestore.client()


def get_storage_bucket():
    """Get Firebase Storage bucket"""
    from firebase_admin import storage
    return storage.bucket()
