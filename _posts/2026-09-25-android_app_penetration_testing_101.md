---
title: "Android App Pentesting 101"
categories: Lab
tags: pentesting android
toc: true
mermaid: ture
---

This lab is a white-box pentest of a simple Android app I just made. It provides full access to the app's source and compiled code, allowing us to use Frida's method-hooking technique to intercept and manipulate the app's runtime logic directly.

Lab components: Android Studio, Android Studio's virtual device, Android Debugging Bridge (ADB), the `frida` CLI, and the `frida` server.

This lab is inspired by Frida Labs https://github.com/DERE-ad2001/Frida-Labs

# White-Box Android App Pentesting Demo

## App Building

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260920190353.png)

`MainActivity`:

```
public class MainActivity extends AppCompatActivity {  
    int key = new Random().nextInt(100);  
  
    @Override  
    protected void onCreate(Bundle b) {  
        super.onCreate(b);  
        setContentView(R.layout.activity_main);  
    }  
  
    public void check(View v) {  
        String s = ((EditText) findViewById(R.id.input)).getText().toString();  
        int x = s.isEmpty() ? 0 : Integer.parseInt(s);  
        ((TextView) findViewById(R.id.result)).setText(  
                x + key == 100 ? "FLAG{" + Integer.toHexString(x * 7919 ^ key * 104729) + "}" : "Wrong");  
    }  
}
```

Trying the app's functionality:

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260920190519.png)

From the code and the interface, we understand that we have to enter the correct guess, from 1 to 99. The correct value is determined at runtime, and the key retains its value as long as the app is running and the instance remains active.

### Getting the `apk` File

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260922150413.png)

It is saved at `C:\Users\raneem\AndroidStudioProjects\MyApplication\app\build\outputs\apk\debug`.

```
PS C:\Users\raneem\AndroidStudioProjects\MyApplication> ls .\app\build\outputs\apk\debug\app-debug.apk


    Directory: C:\Users\raneem\AndroidStudioProjects\MyApplication\app\build\outputs\apk\debug


Mode                 LastWriteTime         Length Name                                                                                                                                                                          
----                 -------------         ------ ----                                                                                                                                                                          
-a----         9/22/2026   2:53 PM       12027731 app-debug.apk    
```

Let's move it to my working directory and rename it to `myapplication.apk`:

```
cp .\app\build\outputs\apk\debug\app-debug.apk C:\Users\raneem\android-reversing-demo\myapplication.apk
```

## ADB

Android debugging bridge is used to give us access to the virtual device's shell, and connects automatically when the android emulator by android studio is started.
First for debugging we need root privilege on the virtual phone's shell.

```
PS C:\Users\raneem\android RE> adb root
adbd is already running as root
```

Install the app using `adb`:

```
adb install .\app\build\outputs\apk\debug\app-debug.apk
```

It is already installed on my virtual device because it was running in Android Studio during the building stage.

## Static Reversing using `jadx`

After opening the `apk` file and navigating to `Source code\com\example.myapplication\MainActivity`, we find the main class.

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260922152438.png)

At this point, we would be analyzing the app's code. However, since this is a white-box penetration test and we already reviewed the code during the app-building stage, let's move on to the next section.

## Dynamic Reverse Engineering using `frida`

![[Frida labs#Frida tool]]

### Writing `JavaScript` Code

The code below is executed at runtime to manipulate the app's behavior. Method hooking is Frida's technique for applying Dynamic Binary Instrumentation (DBI), which includes two tasks: code injection (our JavaScript code) and module-load interception, which means finding and reading the target module in memory. To understand this, let's look at the following example:

 ```
Java.perform(function () {

var MainActivity = Java.use("com.example.myapplication.MainActivity"); // 1

MainActivity.check.implementation = function (v) {  // 2

    console.log('[check] key=' + this.key.value);  // 3
    return this.check(v);   
};
});
 ```

To break down the code:
1. First, we specify the module to intercept, which is `MainActivity`.
2. Then, we specify the target method to instrument by assigning our code through the `.implementation` method.
3. Finally, we add our code.

This code does not change anything; it simply reads the `key` value, which is randomly generated when `onCreate()` is called in `MainActivity` at runtime.
To hook this script with `frida`, use the following command:

```
PS C:\Users\raneem\android-reversing-demo> frida -U "My Application" -l .\hook.js
```

Here's what it looks like when the user interacts with the app.

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260922170128.png)

Since the key does not change on a second submission, I could simply enter `89` as the input and get the flag. However, I want to take a different approach.
Let's manipulate the key's value instead.

```
Java.perform(function () {

var MainActivity = Java.use("com.example.myapplication.MainActivity");

MainActivity.check.implementation = function (v) {

    this.key.value = 50
    console.log('[check] key=' + this.key.value);
    return this.check(v);   
};
});
```

During the first interaction, it changes `key` to 50, as shown. When I click Submit, it prints 50.

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260922171951.png)

Then, simply entering the value that completes 100, which is 50 (100 = 50 + 50), satisfies the flag condition in the `check` function: `((TextView) findViewById(R.id.result)).setText(this.key + x == 100 ? "FLAG{" + Integer.toHexString((x * 7919) ^ (this.key * 104729)) + "}" : "Wrong");`.

![](/assets/images/lab/android-app-penetration-testing-101/Pasted%20image%2020260922172420.png)

There is also a more advanced approach in which the JavaScript script reads the `EditText` (user input) and changes the `key` value based on it, but that is all for now.

Thanks for reading!
