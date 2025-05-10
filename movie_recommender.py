import pandas as pd
import json
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Load your cleaned dataset
movies_cleaned = pd.read_csv('resources/TMDB_movie_dataset_v11_cleaned.csv', index_col=0)

# If genres/keywords are strings representing lists (like "['action', 'thriller']"), evaluate them
import ast
def safe_eval(val):
    try:
        return ast.literal_eval(val) if isinstance(val, str) and val.startswith('[') else val
    except:
        return val

movies_cleaned['genres'] = movies_cleaned['genres'].apply(safe_eval)
movies_cleaned['keywords'] = movies_cleaned['keywords'].apply(safe_eval)

# Now join if it's a list, else leave as-is
movies_cleaned['genres'] = movies_cleaned['genres'].apply(lambda x: ' '.join(x) if isinstance(x, list) else x)
movies_cleaned['keywords'] = movies_cleaned['keywords'].apply(lambda x: ' '.join(x) if isinstance(x, list) else x)

# Replace NaN values with "Not available"
movies_cleaned = movies_cleaned.fillna("Not available")

# Filter for English language movies
movies_cleaned = movies_cleaned[movies_cleaned['original_language'] == 'en']

# Sort by popularity (descending) to prioritize popular movies
movies_cleaned = movies_cleaned.sort_values(by='popularity', ascending=False)

# Combine genres and keywords
movies_cleaned['text'] = (movies_cleaned['genres'] + ' ' + movies_cleaned['keywords'] + ' ' + movies_cleaned['overview']).str.lower()
movies_cleaned = movies_cleaned[movies_cleaned['text'].str.strip().astype(bool)]

# Initialize user input
user_input = []
user_genres = []

# Read "selected_movies.json" and extract keywords
try:
    with open('selected_movies.json', 'r') as f:
        selected_movies = json.load(f)
        for movie in selected_movies:
            keywords = movies_cleaned[movies_cleaned['title'].str.lower() == movie.lower()]['genres']
            if not keywords.empty:
                user_input.extend(keywords.iloc[0].split())
except FileNotFoundError:
    print("selected_movies.json not found. Skipping.")

# Read "user_genres.json" and add genres to user_input
try:
    with open('user_genres.json', 'r') as f:
        user_genres = json.load(f)
        user_input.extend([genre.lower() for genre in user_genres])
except FileNotFoundError:
    print("user_genres.json not found. Skipping.")

# Remove duplicates from user_input
user_input = list(set(user_input))
# Remove rows from movies_cleaned associated with movie titles in user input
movies_cleaned = movies_cleaned[~movies_cleaned['title'].str.lower().isin([movie.lower() for movie in selected_movies])]

# Vectorize the combined text
vectorizer = TfidfVectorizer(stop_words='english')
tfidf_matrix = vectorizer.fit_transform(movies_cleaned['text'])

# Combine user input into a single text
user_text = ' '.join(user_input)
user_vec = vectorizer.transform([user_text])

# Compute similarity
cosine_similarities = cosine_similarity(user_vec, tfidf_matrix).flatten()

# Assign similarity scores
movies_cleaned['similarity'] = cosine_similarities

# Filter recommendations if "family" is in user_genres
if "family" in user_genres:
    movies_cleaned = movies_cleaned[movies_cleaned['genres'].str.contains("family", case=False, na=False)]

# Get top 100 recommendations
recommendations = movies_cleaned.sort_values(by=['similarity', 'popularity'], ascending=[False, False]).head(100)

# Save recommendations to a JSON file
recommendations_list = recommendations[['title', 'release_date', 'genres', 'keywords', 'overview', 'similarity']].to_dict(orient='records')
with open('recommendations.json', 'w') as f:
    json.dump(recommendations_list, f, indent=4)

print("Recommendations saved to recommendations.json")