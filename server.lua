local socket = require("socket")
local json = require("dkjson")
local f = require("file_")

-- Load the genres json file into a table
local genres_json = f.read_file("genres.json")
local data = json.decode(genres_json, 1, nil)
local genres = data.genres
local user_input = {}
local index = 1

local result = {}

local curr_user_loc

-- -- This will be where we load the movie names into a table
-- local names_json = f.read_file("/resources/movies.json")
-- local names_data = json.decode(names_json, 1, nil)
-- local movie_names = names_data.data
-- Handle the movie recommendation system
local function run_movie_rec()
    print("Running script...")
    local handle = io.popen("python3 movie_recommender.py")
    result = handle:read("*a")  -- read all output
    handle:close()
    print("Script ran successfully, answers saved.")
end

local function get_mime_type(path)
    if path:match("%.html$") then return "text/html"
    elseif path:match("%.jpg$") then return "image/jpeg"
    elseif path:match("%.png$") then return "image/png"
    elseif path:match("%.css$") then return "text/css"
    elseif path:match("%.js$") then return "application/javascript"
    elseif path:match("$.json$") then return "application/json"
    else return "text/plain" end
end

local function send(content, client, path)
    if content then
        local mime = get_mime_type(path)
        -- Ensure JSON response includes the correct headers
        if mime == "application/json" then
            client:send("HTTP/1.1 200 OK\r\n")
            client:send("Content-Type: " .. mime .. "\r\n")
            client:send("Content-Length: " .. #content .. "\r\n")
            client:send("Connection: close\r\n\r\n")
            client:send(content)
        else
            -- Other content types (HTML, CSS, JS)
            client:send("HTTP/1.1 200 OK\r\n")
            client:send("Content-Type: " .. mime .. "\r\n")
            client:send("Content-Length: " .. #content .. "\r\n")
            client:send("Connection: close\r\n\r\n")
            client:send(content)
        end
    else
        client:send("HTTP/1.1 404 Not Found\r\n")
        client:send("Content-Type: text/plain\r\n\r\n")
        client:send("404 - Not Found")
    end
end

local function handle_path(path)
    if path == "/" or path == "/index" or path == "/index.html" then
        return "/index.html"
    elseif path == "/genre_component.html" then
        return "/genre_component.html"
    elseif path == "/no" then
        return "no"
    elseif path == "/yes" then
        return "yes"
    elseif path == "/top5_component.html" then
        return "/top5_component.html"
    elseif path == "/matches.html" then
        return "/matches.html"
    elseif path == "/movie_recommendations.html" then
        return "/movie_recommendations.html"
    else
        return path
    end
end



local function handle_request(client)
    local request = client:receive("*l")
    if not request then return end

    local method, path = request:match("^(%w+)%s+(.-)%s+HTTP")
    path = handle_path(path)
    curr_user_loc = "." .. path

    -- Handle saving movies
    if path == "/save_movies" and method == "POST" then
        -- Read headers to get Content-Length
        local headers = {}
        while true do
            local line = client:receive("*l")
            if not line or line == "" then break end
            local key, value = line:match("^(.-):%s*(.*)")
            if key and value then
                headers[key:lower()] = value
            end
        end

        -- Get Content-Length and read the body
        local content_length = tonumber(headers["content-length"])
        if content_length then
            local body = client:receive(content_length)
            print("Body received:", body)

            local movies_data = json.decode(body) -- Decode the JSON body
            if movies_data and movies_data.movies then
                local file = io.open("selected_movies.json", "w") -- Open the file for writing
                file:write(json.encode(movies_data.movies, { indent = true })) -- Save the movies as JSON
                file:close()

                -- Send a success response
                client:send("HTTP/1.1 200 OK\r\n")
                client:send("Content-Type: text/plain\r\n\r\n")
                client:send("Movies saved successfully!")

                path = "/movie_recommendations.html"
                curr_user_loc = "." .. path
            else
                -- Send an error response
                client:send("HTTP/1.1 400 Bad Request\r\n")
                client:send("Content-Type: text/plain\r\n\r\n")
                client:send("Invalid data")
            end
        else
            -- Send an error response if Content-Length is missing
            client:send("HTTP/1.1 411 Length Required\r\n")
            client:send("Content-Type: text/plain\r\n\r\n")
            client:send("Content-Length header is missing")
        end

        run_movie_rec()
    end

    -- Serve movies.json
    if path:match("movies") then
        local content = f.read_file("movies.json")
        send(content, client, path)
        return
    end

    -- Serve recommendations.json with proper content type
    if path:match("recommendations.json") then
        local content = f.read_file("recommendations.json")
        if content then
            send(content, client, path)  -- Ensure we're sending the content correctly
        else
            client:send("HTTP/1.1 404 Not Found\r\n")
            client:send("Content-Type: text/plain\r\n\r\n")
            client:send("Recommendations file not found")
        end
        return
    end

    if path == "yes" or path == "no" then
        if path == "yes" then
            table.insert(user_input, genres[index])
        end

        index = index + 1

        if index >= #genres then
            path = "/top5_component.html"
            curr_user_loc = "." .. path
            local file = io.open("selected_movies.json", "w") -- Open the file for writing
            file:write(json.encode(user_input, { indent = true })) -- Save the movies as JSON
            file:close()

        else
            path = "/genre_component.html"
            curr_user_loc = "." .. path
        end
    end

    local is_binary = path:match("%.jpg$") or path:match("%.png$")
    local content = f.read_file(curr_user_loc, is_binary)
    if not content then
        print("File not found: " .. tostring(curr_user_loc))
        send(nil, client, path)
        return
    end

    -- print("DEBUG: " .. method .. " " .. curr_user_loc .. " " .. path .. "\n" .. genres[index] .. " " .. index)

    if content:match("genres") then
        -- Replace the word 'genres' with a single genre (choose the first genre for simplicity)
        local replaced_content = content:gsub("genres", genres[index])  -- Replace with the first genre (or any other logic)
        
        -- Send the modified content
        send(replaced_content, client, path)
    else
        if path:match("index") and index > 1 then
            index = 1
            user_input = {}
        end
        send(content, client, path)
    end
end

-- Create server
local server = assert(socket.bind("*", 8080))
print("Server running on http://localhost:8080")

while true do
    local client, err = server:accept()
    if client then
        client:settimeout(1)
        local success, err = pcall(handle_request, client)
        if not success then
            print("Error handling request:", err)
        end
        client:close()
    elseif err ~= "timeout" then
        print("Server accept error:", err)
    end
end
