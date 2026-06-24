/**
 * @class       SVMX_Frontec_TestDataFactory  (corrected)
 * @description Shared factory used by PM Plan bulk-update tests.
 *
 * ROOT CAUSE:  createPMPlans() line 17 executed a SOQL query that returned
 *              no rows and assigned the result directly to a single SObject
 *              variable, throwing:
 *                  System.QueryException: List has no rows for assignment to SObject
 *
 *              Both testInvokePMPlanBulkUpdateFail1 and
 *              testInvokePMPlanBulkUpdateSuccess shared this factory method,
 *              so fixing it once resolves both failures.
 *
 * FIX:         (1) Use a List<> for the query; insert the record if absent.
 *              (2) Expose a @TestSetup-friendly initialise() method so all
 *                  prerequisite parents (Account, Pricebook, etc.) exist
 *                  before createPMPlans() is called.
 */
public class SVMX_Frontec_TestDataFactory {

    // ── Prerequisite setup ────────────────────────────────────────────────────

    /**
     * Creates all prerequisite records needed by the factory.
     * Call this from @TestSetup in each test class.
     */
    public static void initialise() {
        // Insert Account if one does not already exist.
        List<Account> accts = [
            SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1
        ];
        if (accts.isEmpty()) {
            insert new Account(Name = 'Test Account');
        }

        // Insert standard Pricebook entry if absent.
        Id stdPricebookId = Test.getStandardPricebookId();

        List<Product2> prods = [
            SELECT Id FROM Product2 WHERE Name = 'Test PM Product' LIMIT 1
        ];
        if (prods.isEmpty()) {
            Product2 prod = new Product2(
                Name     = 'Test PM Product',
                IsActive = true
            );
            insert prod;

            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id   = stdPricebookId,
                Product2Id     = prod.Id,
                UnitPrice      = 100,
                IsActive       = true
            );
            insert pbe;
        }
    }

    // ── PM Plan factory ───────────────────────────────────────────────────────

    /**
     * Creates and inserts a list of PM Plan records.
     *
     * LINE 17 FIX: The old code did:
     *     Account a = [SELECT Id FROM Account WHERE Name='Test Account'];
     *                 ^^^ throws QueryException when no row exists
     *
     * New code uses a List<> with a fallback insert so the query never
     * throws, regardless of test execution order.
     *
     * @param numberOfPlans  How many SVMX_PM_Plan__c records to create.
     * @return               Inserted PM Plan records.
     */
    public static List<SVMX_PM_Plan__c> createPMPlans(Integer numberOfPlans) {

        // ── LINE 17 FIX ───────────────────────────────────────────────────────
        List<Account> accts = [
            SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1
        ];
        if (accts.isEmpty()) {
            Account fallback = new Account(Name = 'Test Account');
            insert fallback;
            accts.add(fallback);
        }
        Account account = accts[0];   // safe — list is guaranteed non-empty
        // ─────────────────────────────────────────────────────────────────────

        List<SVMX_PM_Plan__c> pmPlans = new List<SVMX_PM_Plan__c>();
        for (Integer i = 0; i < numberOfPlans; i++) {
            pmPlans.add(new SVMX_PM_Plan__c(
                Name                  = 'Test PM Plan ' + i,
                SVMX_Account__c       = account.Id,
                SVMX_Active__c        = true,
                SVMX_Frequency__c     = 'Monthly',
                SVMX_StartDate__c     = Date.today(),
                SVMX_NextDueDate__c   = Date.today().addDays(30)
            ));
        }

        insert pmPlans;
        return pmPlans;
    }

    /**
     * Convenience overload — creates a single PM Plan.
     */
    public static SVMX_PM_Plan__c createPMPlan() {
        return createPMPlans(1)[0];
    }
}


// =============================================================================
// TEST CLASS
// =============================================================================

/**
 * @class       SVMX_Frontec_PmPlanBulkUpdateHandler_UT  (corrected)
 * @description Tests for the PM Plan bulk-update handler.
 *
 * ROOT CAUSE:  Both test methods called SVMX_Frontec_TestDataFactory.createPMPlans()
 *              which at line 17 assigned a SOQL result to a single SObject.
 *              No Account record existed at query time → QueryException.
 *
 * FIX:         Call SVMX_Frontec_TestDataFactory.initialise() in @TestSetup
 *              so the Account (and other parents) are guaranteed to exist
 *              before any test method runs.
 */
@IsTest
private class SVMX_Frontec_PmPlanBulkUpdateHandler_UT {

    // ── @TestSetup: runs once, data shared across all test methods ────────────
    @TestSetup
    static void setup() {
        // Guarantees Account + Pricebook entries exist before any test runs.
        SVMX_Frontec_TestDataFactory.initialise();
    }

    // ── Failure path ──────────────────────────────────────────────────────────

    /**
     * Verifies that the bulk-update handler returns an error / does not
     * process PM Plans when invoked with invalid input.
     *
     * Previously threw QueryException at createPMPlans line 17.
     * Now @TestSetup guarantees the Account exists before this method runs.
     */
    @IsTest
    static void testInvokePMPlanBulkUpdateFail1() {

        // ── Arrange ───────────────────────────────────────────────────────────
        // createPMPlans() can now safely query the Account inserted in @TestSetup.
        List<SVMX_PM_Plan__c> pmPlans = SVMX_Frontec_TestDataFactory.createPMPlans(2);

        // Pass an invalid / empty wrapper to trigger the failure path.
        SVMX_Frontec_PmPlanBulkUpdateHandler.UpdateRequest invalidRequest =
            new SVMX_Frontec_PmPlanBulkUpdateHandler.UpdateRequest();
        invalidRequest.pmPlanIds = new List<Id>();   // empty — should fail

        // ── Act ───────────────────────────────────────────────────────────────
        Test.startTest();
            SVMX_Frontec_PmPlanBulkUpdateHandler.UpdateResponse response =
                SVMX_Frontec_PmPlanBulkUpdateHandler.invokeBulkUpdate(invalidRequest);
        Test.stopTest();

        // ── Assert ────────────────────────────────────────────────────────────
        System.assertNotEquals(null, response, 'Response should not be null.');
        System.assertEquals(false, response.isSuccess,
            'Handler should return failure for empty PM Plan ID list.');
        System.assertNotEquals(null, response.errorMessage,
            'An error message should be populated on failure.');
    }

    // ── Success path ──────────────────────────────────────────────────────────

    /**
     * Verifies that the bulk-update handler successfully updates PM Plans
     * when invoked with valid input.
     *
     * Previously threw QueryException at createPMPlans line 17.
     */
    @IsTest
    static void testInvokePMPlanBulkUpdateSuccess() {

        // ── Arrange ───────────────────────────────────────────────────────────
        List<SVMX_PM_Plan__c> pmPlans = SVMX_Frontec_TestDataFactory.createPMPlans(3);

        List<Id> pmPlanIds = new List<Id>();
        for (SVMX_PM_Plan__c plan : pmPlans) {
            pmPlanIds.add(plan.Id);
        }

        SVMX_Frontec_PmPlanBulkUpdateHandler.UpdateRequest validRequest =
            new SVMX_Frontec_PmPlanBulkUpdateHandler.UpdateRequest();
        validRequest.pmPlanIds = pmPlanIds;

        // ── Act ───────────────────────────────────────────────────────────────
        Test.startTest();
            SVMX_Frontec_PmPlanBulkUpdateHandler.UpdateResponse response =
                SVMX_Frontec_PmPlanBulkUpdateHandler.invokeBulkUpdate(validRequest);
        Test.stopTest();

        // ── Assert ────────────────────────────────────────────────────────────
        System.assertNotEquals(null, response, 'Response should not be null.');
        System.assertEquals(true, response.isSuccess,
            'Handler should return success for valid PM Plan IDs.');

        // Verify the PM Plans were actually updated in the database.
        List<SVMX_PM_Plan__c> updatedPlans = [
            SELECT Id, SVMX_LastProcessedDate__c
            FROM   SVMX_PM_Plan__c
            WHERE  Id IN :pmPlanIds
        ];

        System.assertEquals(3, updatedPlans.size(),
            'All 3 PM Plans should have been processed.');

        for (SVMX_PM_Plan__c plan : updatedPlans) {
            System.assertNotEquals(null, plan.SVMX_LastProcessedDate__c,
                'LastProcessedDate should be set after bulk update.');
        }
    }
}
