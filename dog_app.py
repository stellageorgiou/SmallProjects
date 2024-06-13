import json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn 

app = FastAPI()

# Define the path to the JSON inventory file
INVENTORY_FILE = "data/sample_inventory.json"

# Dog Breed model
class Breed(BaseModel):
    breed: str
    size: str
    temperament: str
    energy_level: str
    coat_type_and_maintenance: str
    trainability: str

# Utility functions to manage inventory data
def read_inventory():
    try:
        with open(INVENTORY_FILE, "r") as file:
            return json.load(file)
    except FileNotFoundError:
        return []

def write_inventory(data):
    with open(INVENTORY_FILE, "w") as file:
        json.dump(data, file, indent=4)

@app.get("/")
def root():
    return {"message": "Welcome to the Dog Inventory API"}

# Endpoint to list all dog breeds in the inventory
from typing import List

@app.get("/breeds", response_model=List[Breed])
def get_breeds():
    inventory = read_inventory()
    return inventory

# Endpoint to add a new dog breed to the inventory
@app.post("/breeds", status_code=201)
def add_breed(breed: Breed):
    inventory = read_inventory()
    inventory.append(breed.dict())
    write_inventory(inventory)
    return breed

# Endpoint to get a specific dog breed by breed
from fastapi import Path

@app.get("/breeds/{breed}", response_model=Breed)
def get_breed_by_name(breed: str = Path(..., title="Breed Name")):
    inventory = read_inventory()
    for item in inventory:
        if item["breed"].lower() == breed.lower():
            return item
    raise HTTPException(status_code=404, detail=f"Breed '{breed}' not found")

# Endpoint to delete a dog breed from the inventory by breed name

from fastapi import HTTPException, Path

@app.delete("/breeds/{breed}", status_code=200)
def delete_breed_by_name(breed: str = Path(..., title="Breed Name")):
    inventory = read_inventory()
    print(f"Inventory before deletion: {inventory}")

    # Filter out the breed to delete
    updated_inventory = [item for item in inventory if item["breed"].lower() != breed.lower()]
    print(f"Updated inventory after deletion: {updated_inventory}")

    if len(updated_inventory) < len(inventory):
        write_inventory(updated_inventory)
        return {"message": f"Breed '{breed}' deleted successfully"}
    else:
        raise HTTPException(status_code=404, detail=f"Breed '{breed}' not found")

    

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8001)