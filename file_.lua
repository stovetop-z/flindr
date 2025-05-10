local function read_file(path, binary)
    local mode = binary and "rb" or "r"
    local file = io.open(path, mode)
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local file = {read_file = read_file}
return file