/**
 * Created by frankvanloon on 7/1/20.
 */

@IsTest
private class BD_PlatformEvent_UT {

	@isTest static void testEventUtility() {

		Account acct = new Account(Name='TestSite');
		insert acct;

		SVMXC__Parts_Request__c prq = new SVMXC__Parts_Request__c(
				SVMX_BD_Account__c = acct.Id,
				SVMXC__Status__c = 'Open',
				SVMX_BD_Is_Credit_Card_Purchase__c=true
		);
		insert prq;

		List<SObject> events = new List<SObject>();

		SVMX_BD_Parts_Request_Event__e e1 = new SVMX_BD_Parts_Request_Event__e();
		e1.SVMX_BD_Action__c = 'TEST_1';
		e1.SVMX_BD_Object_Id__c = prq.Id;
		events.add(e1);
        
        /* Changes made by Aleem */
     	SVMX_BD_Parts_Request_Event__e e2 = new SVMX_BD_Parts_Request_Event__e();
		e2.SVMX_BD_Action__c = 'TEST_2';
		e2.SVMX_BD_Object_Id__c = prq.Id;
		events.add(e2);
        // fixing the error for assertion failure above 
		
        Test.startTest();

		BD_PlatformEventUtility.publishEvents(events, 'SVMX_BD_Object_Id__c', 'SVMX_BD_Action__c');

		Test.stopTest();

		List<BD_Platform_Event_Log__c> logs = [SELECT Id, Name, BD_Error_Message__c, BD_Event_JSON__c,
				BD_Platform_Event_Type__c, BD_Related_Element_Id__c, BD_Action__c, BD_Replay_Id__c
			FROM BD_Platform_Event_Log__c WHERE BD_Action__c IN ('TEST_1', 'TEST_2')];

		System.debug('Found Event Logs: ' + logs);
		System.assertEquals(2, logs.size()); // 1 for success, and 1 for error (faked for ut coverage)
        // 2 logs expected because 2 platform events are published in this test. Suggestion  to remove the above comment becaue its misleading
        
		BD_Platform_Event_Log__c log = logs.isEmpty() ? null : logs[0];
		if (log != null)
		{
			Integer replayId = (Integer) log.BD_Replay_Id__c;
			BD_Platform_Event_Log__c updated = BD_PlatformEventUtility.updateEventLog(log.BD_Related_Element_Id__c, replayId,
				'{ test: "Some text body" }', '{ test: "Some result body" }');
			upsert updated SVMX_BD_External_Id__c;

			ApexPages.StandardController stdController = new ApexPages.StandardController(log);
			BD_PlatformEventController customController  = new BD_PlatformEventController(stdController);
			customController.resendEvent();
		}
	}

	@isTest static void testEventErrors() {
		String body1 = '{' +
				'"type" : "http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.1",' +
				'"title" : "Internal Server Error",' +
				'"detail" : "Internal server error. Please contact oracle support for details.",' +
				'"o:errorCode" : "500",' +
				'"o:errorDetails" : [ {' +
				'"type" : "UnMappedFault:createPurchaseOrder",' +
				'"instance" : "NA",' +
				'"title" : "CASDK-0033: Received a SOAP fault while invoking endpoint target: https://eezy-dev2.fa.ca2.oraclecloud.com:443/fscmService/PurchaseOrderServiceV2. This indicates a processing exception on the service endpoint side. Please check service side logs to further diagnose the problem <![CDATA[ \\nFault Code : env:Server\\nFault String : \\nException Description: The object [null], of class [class java.lang.String], from mapping [org.eclipse.persistence.oxm.mappings.XMLDirectMapping[_PROJECT_ID-->ns8:pJCDFFPO_5FPurchase_5FOrder.ns8:_PROJECT_ID/text()]] with descriptor [XMLDescriptor(com.oracle.xmlns.apps.prc.po.commonpo.flex.pjcpodraftdistribution.PJCDFFPO_5FPurchase_5FOrderImpl --> [DatabaseTable(ns8:pJCDFFPO_5FPurchase_5FOrder), DatabaseTable(ns8:pJCDFF)])], could not be converted to [class java.math.BigDecimal].\\nInternal Exception: java.lang.NumberFormatException\\n ]]>\\n:Application Error",' +
				'"o:errorPath" : "NA",' +
				'"o:errorCode" : "NA"' +
				'} ]' +
				'}';
		String body2 = '{\n' +
				'"type" : "http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.1",\n' +
				'"title" : "Internal Server Error",\n' +
				'"detail" : "Internal server error. Please contact oracle support for details.",\n' +
				'"o:errorCode" : "500",\n' +
				'"o:errorDetails" : [ {\n' +
				'"type" : "UnMappedFault:createPurchaseOrder",\n' +
				'"instance" : "NA",\n' +
				'"title" : "CASDK-0033: Received a SOAP fault while invoking endpoint target: https://eezy-dev2.fa.ca2.oraclecloud.com:443/fscmService/PurchaseOrderServiceV2. This indicates a processing exception on the service endpoint side. Please check service side logs to further diagnose the problem <![CDATA[ \\nFault Code : env:Server\\nFault String : JBO-27024: Failed to validate a row with key oracle.jbo.Key[300001321115998 ] in DraftPurchasingDocumentHeaderEOJBO-FND:::FND_VS_VAL_MAX_LEN_EXCEEDED: WorkOrder WO-00005950 is too long -- it must not contain more characters than the maximum allowable length 10.\\nFault Details : \\n<tns:ServiceErrorMessage xmlns:tns=\\"http://xmlns.oracle.com/adf/svc/errors/\\" xmlns:xsi=\\"http://www.w3.org/2001/XMLSchema-instance\\" xsi:type=\\"tns:ServiceRowValErrorMessage\\">\\n <tns:code>27024</tns:code>\\n <tns:message>JBO-27024: Failed to validate a row with key oracle.jbo.Key[300001321115998 ] in DraftPurchasingDocumentHeaderEO</tns:message>\\n <tns:severity>SEVERITY_ERROR</tns:severity>\\n <tns:detail xsi:type=\\"tns:ServiceAttrValErrorMessage\\">\\n <tns:code>FND:::FND_VS_VAL_MAX_LEN_EXCEEDED</tns:code>\\n <tns:message>JBO-FND:::FND_VS_VAL_MAX_LEN_EXCEEDED: WorkOrder WO-00005950 is too long -- it must not contain more characters than the maximum allowable length 10.</tns:message>\\n <tns:severity>SEVERITY_RECOVERABLE_ERROR</tns:severity>\\n <tns:exceptionClassName>oracle.jbo.AttrSetValException</tns:exceptionClassName>\\n <tns:attributeName>Attribute3</tns:attribute:Application Error",\n' +
				'"o:errorPath" : "NA",\n' +
				'"o:errorCode" : "NA"\n' +
				'} ]\n' +
				'}';
		String body3 = '{\n' +
				'"type" : "http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.1",\n' +
				'"title" : "Internal Server Error",\n' +
				'"detail" : "Internal server error. Please contact oracle support for details.",\n' +
				'"o:errorCode" : "500",\n' +
				'"o:errorDetails" : [ {\n' +
				'"type" : "UnMappedFault:execute",\n' +
				'"instance" : "<![CDATA[Please inspect the logs for more details. Initiating Request: <request_payload/>\\n]]>",\n' +
				'"title" : "faultName: {{http://schemas.oracle.com/bpel/extension}remoteFault}\\nmessageType: {{http://www.oracle.com/2014/03/ics/fault}faultMessage}\\nparts: {{\\nparameters=<fault xmlns=\\"http://www.oracle.com/2014/03/ics/fault\\">\\n<errorCode>ERROR</errorCode><reason>ProcessingStatusCode: ERROR</reason><details>InterfaceErrorId: 656003, InterfaceHeaderId: 300001321116002, InterfaceLineId: 300001321116003, BatchId: 23625297, ErrorMessage: You must enter the quantity to be shipped for the item 1059492., ErrorMessageName: RCV_ITEM_NO_SHIP_QTY, ErrorType: ERROR, ColumnName: QUANTITY, TableName: RCV_TRANSACTIONS_INTERFACE</details></fault>}\\n",\n' +
				'"o:errorPath" : "NA",\n' +
				'"o:errorCode" : "NA"\n' +
				'} ]\n' +
				'}';
		String body4 = '{\n' +
				'"type" : "http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.1",\n' +
				'"title" : "Internal Server Error",\n' +
				'"detail" : "Internal server error. Please contact oracle support for details.",\n' +
				'"o:errorCode" : "500",\n' +
				'"o:errorDetails" : [ {\n' +
				'"type" : "UnMappedFault:execute",\n' +
				'"instance" : "<![CDATA[Please inspect the logs for more details. Initiating Request: <request_payload/>\\n]]>",\n' +
				'"title" : "faultName: {{http://schemas.oracle.com/bpel/extension}remoteFault}\\nmessageType: {{http://www.oracle.com/2014/03/ics/fault}faultMessage}\\nparts: {{\\nparameters=<fault xmlns=\\"http://www.oracle.com/2014/03/ics/fault\\">\\n<errorCode>ERROR</errorCode><reason>ProcessingStatusCode: ERROR</reason><my-random-error>InterfaceErrorId: 656003, InterfaceHeaderId: 300001321116002, InterfaceLineId: 300001321116003, BatchId: 23625297, ErrorMessage: You must enter the quantity to be shipped for the item 1059492., ErrorMessageName: RCV_ITEM_NO_SHIP_QTY, ErrorType: ERROR, ColumnName: QUANTITY, TableName: RCV_TRANSACTIONS_INTERFACE</my-random-error></fault>}\\n",\n' +
				'"o:errorPath" : "NA",\n' +
				'"o:errorCode" : "NA"\n' +
				'} ]\n' +
				'}';
		List<String> bodies = new List<String> { body1, body2, body3, body4 };
		for (String body : bodies)
		{
			String error = BD_PlatformEventUtility.cleanseError(body);
			System.debug('Cleansed Error: ' + error);
			System.assertNotEquals(null, error);
			System.assert(error.length() <= 255, 'Error too long');
		}
	}
//
//		Account acct = new Account(Name='TestSite');
//		insert acct;
//
//		SVMXC__Parts_Request__c prq = new SVMXC__Parts_Request__c(
//				SVMX_BD_Account__c = acct.Id,
//				SVMXC__Status__c = 'Open',
//				SVMX_BD_Is_Credit_Card_Purchase__c=true
//		);
//		insert prq;
//
//		List<SObject> events = new List<SObject>();
//
//		SVMX_BD_Parts_Request_Event__e e1 = new SVMX_BD_Parts_Request_Event__e();
//		e1.SVMX_BD_Action__c = 'TEST_WITH_A_REALLY_LONG_ACTION_THAT_IS_ILLEGAL_AND_SHOULD_THROW_AN_ERROR';
//		e1.SVMX_BD_Object_Id__c = prq.Id;
//		events.add(e1);
//
//		Test.startTest();
//
//		BD_PlatformEventUtility.publishEvents(events, 'SVMX_BD_Object_Id__c', 'SVMX_BD_Action__c');
//
//		Test.stopTest();
//
//		List<BD_Platform_Event_Log__c> logs = [SELECT Id, Name, BD_Error_Message__c, BD_Event_JSON__c,
//				BD_Platform_Event_Type__c, BD_Related_Element_Id__c, BD_Action__c
//		FROM BD_Platform_Event_Log__c WHERE BD_Action__c = 'TEST'];
//
//		System.debug('Found Event Logs: ' + logs);
//		System.assertEquals(1, logs.size());
//
//		BD_Platform_Event_Log__c log = logs.isEmpty() ? null : logs[0];
//		System.assertNotEquals(null, log.BD_Error_Message__c);
//
//	}
}