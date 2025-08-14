import json
import re

# Read the notebook
with open('enterprise_knowledge_ai_demo.ipynb', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix AI.GENERATE syntax - remove MODEL keyword and backticks
content = re.sub(
    r'MODEL `bigquery-public-data\.ml_datasets\.gemini_pro`',
    'MODEL `bigquery-public-data.ml_datasets.gemini_pro`',
    content
)

# Actually, let's fix it properly - the AI functions need different syntax
content = re.sub(
    r'AI\.GENERATE\(\s*MODEL `([^`]+)`',
    r'AI.GENERATE(\1',
    content
)

content = re.sub(
    r'AI\.GENERATE_DOUBLE\(\s*MODEL `([^`]+)`',
    r'AI.GENERATE_DOUBLE(\1',
    content
)

content = re.sub(
    r'AI\.GENERATE_BOOL\(\s*MODEL `([^`]+)`',
    r'AI.GENERATE_BOOL(\1',
    content
)

# Write the fixed content
with open('enterprise_knowledge_ai_demo.ipynb', 'w', encoding='utf-8') as f:
    f.write(content)

print('✅ Fixed AI.GENERATE syntax in notebook!')