# Create and activate virtual environment
python -m venv fastapi-env
.\fastapi-env\Scripts\activate

# Start the fastapi server
uvicorn dog_app:app --host 127.0.0.1 --port 8001 --reload

# API documentation
http://127.0.0.1:8001/docs

# Endpoint to display all breeds
http://127.0.0.1:8001/breeds

# GET specific breed example
http://127.0.0.1:8001/breeds/Scottish%20Terrier

# Use cURL to make a GET request
curl http://127.0.0.1:8001/breeds

# Use cURL to make a POST request
curl -X POST -H "Content-Type: application/json" -d "{\"breed\": \"Jack Russel Terrier\", \"size\": \"Small\", \"temperament\": \"Intelligent, Stubborn, Athletic\", \"energy_level\": \"High\", \"coat_type_and_maintenance\": \"Rough/Smooth variety, Low maintenance\", \"trainability\": \"High\"}" http://127.0.0.1:8001/breeds

# Use cURL to make a DELETE request
curl -X DELETE http://127.0.0.1:8001/breeds/Jack%20Russel%20Terrier

