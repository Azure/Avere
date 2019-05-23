# Applying Export Rules

Export Rules and Export Policies enforce security on the cluster by limiting access to an export on a filer.  Export rules are individual definitions that allow or restrict access by host, network, NIS group, or by the default group.  Export policies are a collection of Export Rules which are applied to a filer's exports, allowing the rules within the policy to be enforced.  In this document we will walk through an example scenario in which we apply export policies that we have created to various filer exports that have junctions in our Global Namespace (GNS).  We will then explain how these export policies will be enforced by the cluster to help secure the GNS.
 
For more information on creating export rules and policies, please review the Cluster Configuration Guide [Managing Exports](https://azure.github.io/Avere/legacy/ops_guide/4_7/html/export_rules_overview.html) section.
EXAMPLE

For our example, we will examine a GNS VServer that has two junctions pointing to two filer exports.  This gives us 3 potential places for us to apply export policies to the cluster.  The first and highest point in the GNS is for the pseudo filesystem (GNS' / directory).  The second point for a junction called /disk1, which points to an export /ifs/foo on the filer isilon, and the third for a junction called /disk2, which points to an export /vol/vol1 on the filer netapp. 
 
For our export policies, we will use three:
 
Default - This rule allows read/write access to everyone.
NetworkA - This rule will allow the network 10.0.0.0/24 read/write access and restrict everyone else.
NetworkB - This rule will allow the network 10.1.0.0/24 read/write access and restrict everyone else.
 
 
IMPLEMENTING EXPORT POLICIES FOR OUR EXAMPLE
 
When applying export policies it's important to remember that they need to be the least restrictive at the highest point in the GNS tree, and then gradually get more restrictive as they move down the tree.  This is because export policies start at the point with which they are implemented and trickle down to all the files and directories underneath them, so if you put a restrictive policy in for /, let's say the NetworkA export policy for example, it will apply to /, /disk1 and /disk2.  That means that only the network 10.0.0.0/24 will be able to access anything within the GNS tree structure and everyone else will be locked out.
 
With these ideas in mind, we can now set up our security structure.  Lets say that we want /disk1 to be accessed by NetworkA and /disk2 to be accessed by NetworkB.  We would set the following export policies: / would stay at Default, /disk1 would be assigned the NetworkA export policy, and /disk2 would be assigned NetworkB export policy.  Figure 1 (next page) shows the GNS structure with the policies applied.
 
 
If we mount / from the client 10.0.0.1 and did an ls, we would see:
 
disk1
disk2
 
If we tried to cd into disk1, we would be successful and would be able to view and work with it's contents.  If we tried to go into disk2 however, the export policy NetworkB would block the request and we would receive an access denied message.  
 
Now, lets say that we change the export policy for / to NetworkB.  Although the client 10.0.0.1 has an export policy that allows it access to /disk1, it would not be able to access it because the export policy for / is now set so that only clients from the 10.1.0.0/24 network  can access the GNS tree.  Since /disk1 is part of that tree, the policy of / supercedes the policy of /disk1.  To allow access for the 10.0.0.1 client, / would need to have an export policy of default, which allows everyone, or NetworkA which allows 10.0.0.0/24 access.
 
CONCLUSION
 
As you can see, when export policies are applied, especially in complex configurations, it can be a challenge to implement them in ways that ensure you are giving everyone the proper access.  The thing to remember is that export policies trickle down from each junction point and that the pseudo filesystem is a point where export policies can be imposed, so if there is a problem with access, you will always want to check both / and the export policy of the junction to ensure both allow access to the client in question.  If you do that, you should be able to troubleshoot access problems fairly easily.
 
SUPPLEMENTAL READING
 
More information regarding export policies and rules can be found at the following links:

https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_export_policies.html
https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_export_rules.html
 
AUTHOR

Cliff Friedel

CHANGELOG

Version 1.0 - Initial creation of the document.
Version 1.1 - Modification to update links for supplemental reading
