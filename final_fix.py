import json

# Read the notebook
with open('enterprise_knowledge_ai_demo.ipynb', 'r', encoding='utf-8') as f:
    notebook = json.load(f)

# Find and fix ALL problematic cells
fixed_count = 0
for i, cell in enumerate(notebook['cells']):
    if cell['cell_type'] == 'code' and 'source' in cell:
        source_text = ''.join(cell['source'])
        
        # Check if this is ANY cell with BigQuery issues
        if ('client = bigquery.Client()' in source_text or 
            'your-bigquery-project-id' in source_text or
            ('import pandas as pd' in source_text)):
            
            print(f"Found problematic cell {i}, fixing...")
            
            # Replace with fixed code
            new_source = [
                "# Setup and Configuration\n",
                "import pandas as pd\n",
                "import numpy as np\n",
                "import json\n",
                "from datetime import datetime, timedelta\n",
                "import warnings\n",
                "warnings.filterwarnings('ignore')\n",
                "\n",
                "# BigQuery setup with service account authentication\n",
                "from google.cloud import bigquery\n",
                "from google.oauth2 import service_account\n",
                "\n",
                "# Path to your service account key\n",
                "key_path = r\"C:\\Users\\msaya\\Downloads\\analog-daylight-469011-e9-b89b0752ca82.json\"\n",
                "\n",
                "print(\"Loading BigQuery credentials...\")\n",
                "\n",
                "# Create credentials object\n",
                "credentials = service_account.Credentials.from_service_account_file(key_path)\n",
                "\n",
                "# Initialize BigQuery client with credentials\n",
                "client = bigquery.Client(credentials=credentials, project=credentials.project_id)\n",
                "\n",
                "project_id = credentials.project_id\n",
                "dataset_id = 'enterprise_knowledge_ai'\n",
                "\n",
                "print(\"BigQuery client initialized successfully!\")\n",
                "print(f\"Project ID: {project_id}\")\n",
                "print(f\"Dataset: {dataset_id}\")\n",
                "print(f\"Started: {datetime.now()}\")\n",
                "print(\"BigQuery AI implementation ready!\")"
            ]
            
            cell['source'] = new_source
            fixed_count += 1
            print(f"Cell {i} fixed!")

# Write the fixed notebook
with open('enterprise_knowledge_ai_demo.ipynb', 'w', encoding='utf-8') as f:
    json.dump(notebook, f, indent=1, ensure_ascii=False)

print(f"Notebook fixed! {fixed_count} cells updated.")