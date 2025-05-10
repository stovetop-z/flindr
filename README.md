# Flindr
I present a movie match-making service. You give a *yes* or *no* to genres, give your top 5 selections of movies you would watch again, we do the rest.

## How to Run

#### Download/Install Requirements
This assumes you already have python and pip installed.
1. Install the python dependencies: 
```bash 
pip install -r requirements.txt
```
2. Download and install [lua](https://www.lua.org/download.html) as described in the website
3. To use the libraries integrated into this website, you also will need to install [luarocks](https://github.com/luarocks/luarocks/wiki/Download) (a lua library manager).
4. Install the lua dependencies: 
```bash
luarocks install dkjson
```

#### Run
The program will automatically launch through port `8080`. You can change that in the `server.lua` file. 
```bash
lua server.lua
```

#### Open Application
Go to http://localhost:8080 and tryout the application!