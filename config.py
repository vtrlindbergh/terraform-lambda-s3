import os
from dotenv import load_dotenv

class CredentialsError(Exception):
    pass

class MissingEnvFileError(CredentialsError):
    def __init__(self, env_path):
        self.message = f".env file not found at: {env_path}"
        super().__init__(self.message)

class MissingCredentialError(CredentialsError):
    def __init__(self, credential_name):
        self.message = f"Missing '{credential_name}' in .env file."
        super().__init__(self.message)

class Credentials:
    def __init__(self, env_path: str):
        self.env_path = env_path

    def get_credentials(self) -> tuple[str]:
        if not os.path.exists(self.env_path):
            raise MissingEnvFileError(self.env_path)

        load_dotenv(self.env_path)
        
        bucket_name = os.getenv("BUCKET_NAME")
        filename = os.getenv("FILENAME")

        if not bucket_name:
            raise MissingCredentialError("BUCKET_NAME")
        if not filename:
            raise MissingCredentialError("FILENAME")

        return bucket_name, filename
