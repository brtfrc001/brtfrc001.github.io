Lab components: Android Studio, Android Studio's virtual device, Android Debugging Bridge (ADB) , `frida` CLI, `frida` server.
This lab is inspired by Frida Labs https://github.com/DERE-ad2001/Frida-Labs
# White box android app PT demo
## App building
![[Attachments/Pasted image 20260920190353.png]]
Main:
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
trying the app functionality
![[Attachments/Pasted image 20260920190519.png]]

What we understand from the code and the interface is that we have to enter the correct guess from 1 to 99 that is only determined at runtime and the key keeps its value as long as the app is running and the instance is still active.
### getting `apk` file
![[Attachments/Pasted image 20260922150413.png]]

it is saved in loc: `C:\Users\raneem\AndroidStudioProjects\MyApplication\app\build\outputs\apk\debug`
```
PS C:\Users\raneem\AndroidStudioProjects\MyApplication> ls .\app\build\outputs\apk\debug\app-debug.apk


    Directory: C:\Users\raneem\AndroidStudioProjects\MyApplication\app\build\outputs\apk\debug


Mode                 LastWriteTime         Length Name                                                                                                                                                                          
----                 -------------         ------ ----                                                                                                                                                                          
-a----         9/22/2026   2:53 PM       12027731 app-debug.apk    
```
let's move it to my working directory and rename to `myapplication.apk`
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
Installing the app using `adb`.
```
adb install .\app\build\outputs\apk\debug\app-debug.apk
```
It is already installed on my virtual device, since it was running in android studio at building stage.
## Static Reversing using `jadx`
Opening the `apk` file and navigating to path: `Source code\com\example.myapplication\MainActivity` We find the main class.
![[Attachments/Pasted image 20260922152438.png]]
At this point we'd be analyzing app code, but since we have a white box penetration testing and had an overview in App Building stage, we already made this point, so let's go to the next section. 
## Dynamic Reverse Engineering using `frida`
![[Frida labs#Frida tool]]
### Writing a `JavaScript` code
 A code that will be executed at runtime and will manipulate our app's behavior, method hooking is `frida`'s own technique in applying Dynamic Binary Instrumentation (DBI) which includes two tasks: code injection (my JS code); module loads interception, which means finding and reading the target module in memory. to understand it, let's look at this example:
 ```
Java.perform(function () {

var MainActivity = Java.use("com.example.myapplication.MainActivity"); // 1

MainActivity.check.implementation = function (v) {  // 2

    console.log('[check] key=' + this.key.value);  // 3
    return this.check(v);   
};
});
 ```

To disseminate the code:
1. First we specify the module load which we will intercept, which is `MainActivity`.
2. Then we specify the target method to be instrumented (injected with our code) using `.implementation` method.
3. Our code here.
This code doesn't change anything it just looks at `key` value that is randomly generated once `onCreate()` in the main is called at runtime.
To hook this script with `frida` use this command line:
 ```
PS C:\Users\raneem\android-reversing-demo> frida -U "My Application" -l .\hook.js
 ```
Here's how it looks like when user interacts with the app.
![[Attachments/Pasted image 20260922170128.png]]
Since the key won't change at a second submit, meaning I can just enter `89` as input and get the flag, I can just do that, but I want to take a different approach.
Let's manipulate the key value instead.
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

At the first interaction it changed `key` to 50 as shown, I click submit it prints 50
![[Attachments/Pasted image 20260922171951.png]]
Then simply entering the value that completes 100 which is 50 (100=50+50) which satisfies the condition of the flag at `((TextView) findViewById(R.id.result)).setText(this.key + x == 100 ? "FLAG{" + Integer.toHexString((x * 7919) ^ (this.key * 104729)) + "}" : "Wrong");` in `check` function.
![[Attachments/Pasted image 20260922172420.png]]
There's also more advanced approach where we're making the JS script read the `editText` (user input) and change the `key` value based on that, but this is all for now.

Thanks for reading!
