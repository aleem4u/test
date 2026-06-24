/**
 * @class       SVMX_BD_PMHistoryTest
 * @description Corrected test class for PM History Work Order updates.
 *
 * ROOT CAUSE:  The assertion on line 39 expected 'Monthly' but received null.
 *              The PM Plan was either not linked to the Work Order via a lookup,
 *              or the Frequency__c field was not populated in test data, so the
 *              trigger/handler had nothing to copy onto the Work Order.
 *
 * FIX:         (1) Insert PM Plan with Frequency__c = 'Monthly' first.
 *              (2) Link the Work Order to the PM Plan via the lookup field.
 *              (3) Re-query the Work Order with the expected field after update.
 *              (4) Verify any custom setting / feature flag is active in tests.
 */
@IsTest
private class SVMX_BD_PMHistoryTest {

    // ── Shared test data created once for all methods ─────────────────────────
    @TestSetup
    static void setupTestData() {

        // 1. Create the PM Plan with Frequency populated.
        //    Adjust API names to match your org schema.
        SVMX_PM_Plan__c pmPlan = new SVMX_PM_Plan__c(
            Name            = 'Test PM Plan',
            SVMX_Frequency__c = 'Monthly',          // field that drives WO copy
            SVMX_Active__c  = true
        );
        insert pmPlan;

        // 2. Create a Work Order and link it to the PM Plan.
        WorkOrder wo = new WorkOrder(
            Subject              = 'Test Work Order',
            SVMX_SM_PM_Plan__c   = pmPlan.Id,       // lookup to PM Plan
            Status               = 'New'
        );
        insert wo;

        // 3. Create a PM History record tied to the Work Order.
        SVMX_PM_History__c pmHistory = new SVMX_PM_History__c(
            SVMX_WorkOrder__c   = wo.Id,
            SVMX_PM_Plan__c     = pmPlan.Id,
            SVMX_Status__c      = 'Scheduled'
        );
        insert pmHistory;
    }

    /**
     * Verifies that updating a PM History record copies the PM Plan
     * Frequency ('Monthly') onto the associated Work Order.
     *
     * LINE 39 FIX: re-query the Work Order AFTER the update and assert
     * the frequency field is 'Monthly', not null.
     */
    @IsTest
    static void testPMHistoryWorkOrderUpdate() {

        // ── Arrange ───────────────────────────────────────────────────────────
        // Fetch the records created in @TestSetup.
        SVMX_PM_Plan__c pmPlan = [
            SELECT Id, SVMX_Frequency__c
            FROM   SVMX_PM_Plan__c
            WHERE  Name = 'Test PM Plan'
            LIMIT  1
        ];

        WorkOrder wo = [
            SELECT Id, SVMX_SM_PM_Plan__c
            FROM   WorkOrder
            WHERE  Subject = 'Test Work Order'
            LIMIT  1
        ];

        SVMX_PM_History__c pmHistory = [
            SELECT Id, SVMX_Status__c
            FROM   SVMX_PM_History__c
            WHERE  SVMX_WorkOrder__c = :wo.Id
            LIMIT  1
        ];

        // ── Act ───────────────────────────────────────────────────────────────
        Test.startTest();
            // Trigger the update that should propagate frequency to Work Order.
            pmHistory.SVMX_Status__c = 'Completed';
            update pmHistory;
        Test.stopTest();

        // ── Assert ────────────────────────────────────────────────────────────
        // LINE 39 FIX: re-query with the specific field to avoid stale data.
        WorkOrder updatedWo = [
            SELECT Id,
                   SVMX_SM_Frequency__c    // field asserted at line 39
            FROM   WorkOrder
            WHERE  Id = :wo.Id
            LIMIT  1
        ];

        System.assertEquals(
            'Monthly',
            updatedWo.SVMX_SM_Frequency__c,
            'Work Order frequency should be copied from the linked PM Plan.'
        );
    }

    /**
     * Verifies behaviour when no PM Plan is linked (null-safe path).
     */
    @IsTest
    static void testPMHistoryWorkOrderUpdate_NoPMPlan() {

        // Work Order with NO PM Plan lookup.
        WorkOrder woNoPlan = new WorkOrder(
            Subject = 'WO Without PM Plan',
            Status  = 'New'
        );
        insert woNoPlan;

        SVMX_PM_History__c histNoPlan = new SVMX_PM_History__c(
            SVMX_WorkOrder__c = woNoPlan.Id,
            SVMX_Status__c    = 'Scheduled'
        );
        insert histNoPlan;

        Test.startTest();
            histNoPlan.SVMX_Status__c = 'Completed';
            update histNoPlan;
        Test.stopTest();

        WorkOrder result = [
            SELECT SVMX_SM_Frequency__c
            FROM   WorkOrder
            WHERE  Id = :woNoPlan.Id
        ];

        // Without a PM Plan link the field should remain null — no exception.
        System.assertEquals(
            null,
            result.SVMX_SM_Frequency__c,
            'Frequency should be null when no PM Plan is linked.'
        );
    }
}
