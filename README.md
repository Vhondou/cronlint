# 🧩 cronlint — Validate system crontab files

`cronlint.sh` is a small POSIX shell script that checks whether a file follows the syntax rules of a **system crontab** (e.g. `/etc/crontab` or files in `/etc/cron.d/`).

It validates that each line has the correct number of fields, uses valid time specifications, contains a valid user field, and ends properly with a newline.  
It also detects CRLF (Windows-style) line endings and misformatted entries.

---

## 🧭 Features

✅ Validates **field count** (`min hr dom mon dow USER COMMAND`)  
✅ Supports **@special** keywords (`@reboot`, `@daily`, `@weekly`, etc.)  
✅ Checks **time field syntax** (lists, ranges, steps, month/day names)  
✅ Validates **value ranges** for all time fields (`minute`, `hour`, `day`, `month`, `weekday`)  
✅ Verifies **USER field**
- must match a valid username pattern (`^[A-Za-z_][A-Za-z0-9_-]*[$]?$`)
- must exist on the system (`getent passwd` or `/etc/passwd`)

✅ Detects **Windows line endings (`CRLF`)**  
✅ Warns if file **does not end with newline**  
✅ Ignores **blank lines**, **comments**, and **environment variable assignments**


---

## 📦 Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/alphapialpha/cronlint.git
cd cronlint
chmod +x cronlint.sh
```

Optionally move it into your `$PATH`:

```bash
sudo mv cronlint.sh /usr/local/bin/cronlint
```

Now you can run it anywhere as `cronlint`.

---

## 🚀 Usage

```bash
cronlint /path/to/crontab-file
```

Example:

```bash
cronlint /etc/crontab
```

### ✅ Valid Example

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Run daily backup as root
0 3 * * * root /usr/local/bin/backup.sh
```

**Output:**
```
OK: no errors.
```

### ❌ Invalid Example

```cron
5 4 23 11 5 cat /etc/crontab
```

**Output:**
```
Line 1: ERROR: user not found: cat
Found 1 error(s).
```

### ⚠️ Warnings Example

File doesn’t end with a newline:

```
WARNING: File does not end with a newline character.
Note: 1 warning(s) reported.
```

File contains Windows CRLF endings:

```
ERROR: File contains Windows CRLF line endings (\r). Convert to LF only.
```

---

## ⚙️ Exit Codes

| Code | Meaning             |
|------|---------------------|
| 0    | OK (no errors)      |
| 1    | Errors found        |
| 2    | Invalid usage       |

---

## 🧠 Notes

- `cronlint` is designed for **system crontabs**, which require a `USER` field.  
- User crontabs created with `crontab -e` do **not** include a user field and will fail validation.  
- The script is **POSIX-compliant** and runs on most UNIX-like systems (Linux, BSD, macOS).  
- It uses only standard utilities: `awk`, `grep`, `tail`, and `od`.

---

## 🧾 License

**MIT License** © 2025 André Pierre Appel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

---

## 💡 Contributing

Pull requests are welcome!  
If you find edge cases (e.g. unusual cron syntax or OS-specific differences), feel free to open an issue or submit a fix.

### Example contribution workflow

```bash
git checkout -b fix-user-validation
# edit cronlint.sh
git commit -am "Improve user validation and field detection"
git push origin fix-user-validation
```

Then open a **Pull Request** on GitHub.

---

## 🧩 Credits

Created with ☕ and 🐧 by André Pierre Appel  
> “Linting is just removing the fluff — even from your crontabs.” 
