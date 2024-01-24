# KURL BASH

An advanced *bash script* to shorten URLs with [YOURLS](https://yourls.org) for **Linux** distributions


![kurl](https://github.com/gerald-drissner/kurl/assets/16115672/d8b4ff83-0f6b-4bf4-a098-9ea3cd35bbc3)

# Installation

## DOWNLOAD the SCRIPT
Assuming you have git installed. Otherwise, install it with sudo pacman -S git
or any other similar command on other Linux distributions.
```bash
git clone https://github.com/gerald-drissner/kurl.git
```

## Make the script executable
```bash
cd kurl
```
```bash
sudo chmod +x kurl.sh
```

## Move the script
Move the script to a directory in your PATH with the command 'sudo mv yourls.sh /usr/local/bin'.
```bash
sudo mv kurls.sh /usr/local/bin
```

## Run the script
Now, you can run the script from anywhere in the terminal by typing 'kurl'.
When you run it for the first time, you can enter the credentials: your yourls server and the signature key.
So just run:
```bash
kurl.sh
```


## Usage

Shorten a long URL :

```bash
kurl https://someverylongdomain.com
```

Shorten a long URL and provide a custom keyword and a custom title :

```bash
kurl https://someverylongurl.com -k test12 --title "Some title"
```

Shorten a URL and receive JSON output:
```bash
$> kurl https://example.com -f json
{
  "url": {
    "keyword": "Nzs",
    "url": "https://example.com",
    "title": "Example Domain",
    "date": "2021-06-06 16:03:44",
    "ip": "127.0.0.1"
  },
  "status": "success",
  "message": "http://example.com added to database",
  "title": "Example Domain",
  "shorturl": "http://sho.rt/Nzs",
  "statusCode": 200
}
```

Display help message :
```bash
kurl --help
```

## License

Do whatever the hell you want with it



