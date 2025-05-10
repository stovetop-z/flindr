import pandas as pd
import json

# Input CSV file
csv_file = 'resources/TMDB_movie_dataset_v11_cleaned.csv'
# Output JSON file
json_file = 'movies_info.json'

# Read CSV into a DataFrame
df = pd.read_csv(csv_file)

# Extract the second column (by index or name)
second_column = df.iloc[:, [1,7,10]]  # get the 2nd, 8th, and 11nth columns

second_column.to_json("selected_columns.json", orient="records", indent=4)
