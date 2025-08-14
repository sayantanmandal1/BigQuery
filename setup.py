from google.cloud import bigquery
from google.oauth2 import service_account

# Path to your downloaded JSON key
key_path = r"C:\Users\msaya\Downloads\analog-daylight-469011-e9-b89b0752ca82.json"

print("Loading credentials from:", key_path)

# Create credentials object
credentials = service_account.Credentials.from_service_account_file(key_path)

print("Project ID:", credentials.project_id)

# Initialize BigQuery client with credentials
client = bigquery.Client(credentials=credentials, project=credentials.project_id)

print("BigQuery client initialized successfully")

# Example: list datasets in the project
print("Listing datasets...")
datasets = list(client.list_datasets())

if datasets:
    print(f"Found {len(datasets)} datasets:")
    for dataset in datasets:
        print(f"  - {dataset.dataset_id}")
else:
    print("No datasets found in this project")
