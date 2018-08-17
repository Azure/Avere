# Access the vFXT cluster
Now that your vFXT cluster is created, you need to configure its storage. In this tutorial, you will access the vFXT cluster by creating an SSH tunnel and accessing the interface with your browser.

## Access with a Linux host
If using a Linux-based client, use an SSH tunneling command like `ssh -L [localPort]:[vFXTmgmtIP]:443 [username]@[controllerPublicIP]`.
For example:
```sh
ssh -L 8443:10.0.0.5:443 ronh@40.117.119.51
```
Enter your SSH password.

## Access with a Windows host
If using PuTTY, add your username@ the public IP address of the controller in the hostname field. 
1. Expand SSH on the left.
1. Click Tunnels. 
1. Enter a source port like 8443. 
1. For the destination, enter the vFXT’s management IP address :443. 
1. Click Add.
1. Click Open.

<img src="images/20-tunnel-numbered-border-75.png">

Enter your SSH password.

## Access 
Open your browser. Navigate to https://127.0.0.1:8443. Depending on your browser, you will need to go to Advanced and Proceed to the page.

<img src="images/21-browser-proceed.png">

Enter the username `admin` and the vFXT password you provided when installing the cluster.

<img src="images/21b-login.png">

Click “Login” or press Enter.
