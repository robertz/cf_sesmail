component {
/*
* Project: mailses
* Author : Robert Zehnder
* Version: 0.1.2011.09.04
* Purpose: cfmail-like implementation to make it easier to send emails through Amazon Simple Email Service
*/
 this.metaData.attributeType = "fixed";
 this.metaData.attributes = {
  from        : { required: true, type: "string" },
  to          : { required: true, type: "string" },
  cc          : { required: false, type: "string", default: "" },
  bcc         : { required: false, type: "string", default: "" },
  failTo      : { required: false, type: "string", default: "" },
  replyTo     : { required: false, type: "string", default: "" },
  subject     : { required: true, type: "string" },
  mailerID    : { required: false, type: "string", default: "cf_sesmail" },
  endPoint    : { required: false, type: "string", default: "" },
  credentials : { required: true, type: "string" },
  name        : { required: false, type: "string", default: "sesResults" },
  sendHeaders : { required: false, type: "struct", default: {} }
 };

 public void function init(required boolean hasEndTag, any parent) {

 }

 public boolean function onStartTag(struct attributes, struct caller) {
  return true;
 }

 public boolean function onEndTag(struct attributes, struct caller) {
  var results = {};
  var awsCredentials = createObject("java", "java.io.File").init(attributes.credentials);
  var creds = createObject("java", "com.amazonaws.auth.PropertiesCredentials").init(awsCredentials);
  var emailService = createObject("java", "com.amazonaws.services.simpleemail.AmazonSimpleEmailServiceClient").init(creds);
  var props = createObject("java", "java.util.Properties");
  var verifyRequest = createObject("java", "com.amazonaws.services.simpleemail.model.VerifyEmailAddressRequest").withEmailAddress(attributes.from);
  if(len(attributes.endPoint)) emailService.setEndPoint(attributes.endPoint);
  
  // Set properties for establishing connection
  props.setProperty("mail.transport.protocol", "aws");
  props.setProperty("mail.aws.user", creds.getAWSAccessKeyId());
  props.setProperty("mail.aws.password", creds.getAWSSecretKey());
  
  // Send email message
  var mailSession = createObject("java", "javax.mail.Session").getInstance(props);
  var mailTransport = createObject("java", "com.amazonaws.services.simpleemail.AWSJavaMailTransport").init(mailSession, JavaCast("null", 0));
  var messageObj = createObject("java", "javax.mail.internet.MimeMessage").init(mailSession);
  var messageRecipientType = createObject("java", "javax.mail.Message$RecipientType");
  var messageFrom = createObject("java", "javax.mail.internet.InternetAddress").init(attributes.from);
  var messageTo = listToArray(attributes.to);
  var messageCC = listToArray(attributes.cc);
  var messageBCC = listToArray(attributes.bcc);
  var messageSubject = attributes.subject;
  var messageBody = arguments.generatedContent;
  var verified = arrayToList(emailService.ListVerifiedEmailAddresses().getVerifiedEmailAddresses()).contains(attributes.from);
  var i = 0;
  
  try {
  	
   // Is the sender verified
   if(!verified){
    var verifyRequest = createObject("java", "com.amazonaws.services.simpleemail.model.VerifyEmailAddressRequest").withEmailAddress(attributes.from);
    try{
     emailService.verifyEmailAddress(verifyRequest);
    }
    catch (any e){
    }
    throw("Email address has not been validated.  Please check the email on account " & attributes.from & " to complete validation.");
   }
   else{
   	
	mailTransport.connect();
	
	messageObj.setFrom(messageFrom);
	for(i = 1; i <= arrayLen(messageTo); i++){
	 messageObj.addRecipient(messageRecipientType.TO, createObject("java", "javax.mail.internet.InternetAddress").init(trim(messageTo[i])));
	}
	   
	if(arrayLen(messageCC)){
	 for(i = 1; i <= arrayLen(messageCC); i++){
	  messageObj.addRecipient(messageRecipientType.CC, createObject("java", "javax.mail.internet.InternetAddress").init(trim(messageCC[i])));
	 }
	}
	   
	if(arrayLen(messageBCC)){
	 for(i = 1; i <= arrayLen(messageBCC); i++){
	  messageObj.addRecipient(messageRecipientType.BCC, createObject("java", "javax.mail.internet.InternetAddress").init(trim(messageBCC[i])));
	 }
	}
	
	// If reply-to was specified, set the reply-to header    
	if(len(attributes.replyTo)){
	 messageObj.addHeader("Reply-To", createObject("java", "javax.mail.internet.InternetAddress").init(attributes.replyTo).toString());
	}
	
	// If fail-to address was specified, set the return-path header   
	if(len(attributes.failTo)){
	 messageObj.addHeader("Return-Path", createObject("java", "javax.mail.internet.InternetAddress").init(attributes.failTo).toString());	
	}
	
	// If the mailerID was specified, set the user-agent header   
	if(len(attributes.mailerID)){
	 messageObj.addHeader("User-Agent", attributes.mailerID);	
	}
	
	// if the sendHeaders attribute was specified, set message headers. This may override attribute values.   
	if(len(structKeyList(attributes.sendHeaders))){
	 for(i in attributes.sendHeaders){
	  messageObj.addHeader(i, attributes.sendHeaders[i]);
	 }   
	}
	
	messageObj.setSubject(messageSubject);
	messageObj.setContent(messageBody, "text/html");
	messageObj.saveChanges();
	
	mailTransport.sendMessage(messageObj, JavaCast("null", 0));
	
	mailTransport.close();
	   
	results['attributes'] = attributes;
	results['max24HourSend'] = emailService.getSendQuota().getMax24HourSend();
	results['getMaxSendRate'] = emailService.getSendQuota().getMaxSendRate();
	results['getSentLast24Hours'] = emailService.getSendQuota().getSentLast24Hours();
	   
	caller[attributes.name] = results;
   } //end else
   
  }
  catch (Any e){
   throw( type = "error", message = "There was an error sending the message", detail = e.message);
  }
  return false;
 }

}
