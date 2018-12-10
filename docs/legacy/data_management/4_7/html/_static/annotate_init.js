/* This script initializes the annotator to allow notes to be added to the page
* It stores information on xlg20a.cc.arriad.com
*
* Author: Josh McIntyre
*
*/ 
$(document).ready(function() {

    var content = $("body").annotator();

    content.annotator("addPlugin", "Store", {
        prefix: "http://10.1.56.29:5000",

        annotationData : {
            "uri" : window.location.href.replace(window.location.hash, "")
        },

        loadFromSearch : {
            "limit" : 20,
            "uri" : window.location.href.replace(window.location.hash, "")
        }
    });

});
