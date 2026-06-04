import json
import re
import os

input_file = r'd:\downloads\songs.txt'
output_file = r'd:\Spotify\assets\tamil_songs.json'

print("Reading file...")
with open(input_file, 'r', encoding='utf-8') as f:
    raw_data = f.read()

print("Fixing concatenated JSON arrays...")
# The file has multiple arrays like ] \n [
# We can fix this by replacing ]\s*\[ with ,
fixed_data = re.sub(r'\]\s*\[', ',', raw_data)

print("Parsing JSON...")
try:
    songs = json.loads(fixed_data)
except Exception as e:
    print(f"Error parsing JSON: {e}")
    exit(1)

print(f"Total songs loaded: {len(songs)}")

# Process each song
processed_songs = []
for i, song in enumerate(songs):
    new_song = {}
    
    # 1. Map old properties, rename composer -> artist, artist -> singers
    new_song['id'] = str(i + 1) # Ensure unique IDs just in case
    new_song['title'] = song.get('title', 'Unknown Title')
    new_song['artist'] = song.get('composer', 'Unknown Composer') # Composer becomes Artist
    new_song['singers'] = song.get('artist', 'Unknown Singers') # Old artist becomes Singers
    new_song['movie'] = song.get('movie', 'Unknown Movie')
    new_song['year'] = song.get('year', '')
    new_song['src'] = song.get('src', '')
    
    # Add genre
    new_song['genre'] = 'Film Soundtrack' # Default genre
    
    # Add img
    # Use a beautiful fallback music image since local assets are missing
    new_song['img'] = "https://i.pinimg.com/736x/5e/04/99/5e049992ef02750dad84fe7d44c061bc.jpg"

    processed_songs.append(new_song)

print("Writing processed data to output file...")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(processed_songs, f, indent=2, ensure_ascii=False)

print("Successfully converted data!")
