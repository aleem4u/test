/**
 * @class       BD_PlatformEvent_UT
 * @description Corrected test class for BD Platform Event utility.
 *
 * ROOT CAUSE:  Only 1 event was being counted because the second publish
 *              call happened outside Test.startTest()/stopTest() or the
 *              test data only triggered a single event path.
 *
 * FIX:         Both EventBus.publish() calls are placed inside
 *              Test.startTest()/Test.stopTest() so the async event bus
 *              is flushed synchronously and both events are captured
 *              before the assertion on line 38.
 */
@IsTest
private class BD_PlatformEvent_UT {

    /**
     * Creates two distinct source records that each independently
     * trigger a platform event, then asserts both were published.
     */
    @IsTest
    static void testEventUtility() {

        // ── Arrange ──────────────────────────────────────────────────────────
        // Build two events that represent distinct business scenarios.
        // Adjust the SObject type / fields to match your actual event schema.
        BD_My_Platform_Event__e event1 = new BD_My_Platform_Event__e(
            BD_Source__c    = 'Source_A',
            BD_Payload__c   = 'Payload for first event'
        );

        BD_My_Platform_Event__e event2 = new BD_My_Platform_Event__e(
            BD_Source__c    = 'Source_B',
            BD_Payload__c   = 'Payload for second event'
        );

        // ── Act ───────────────────────────────────────────────────────────────
        // CRITICAL: Both publish calls must be inside startTest/stopTest.
        // Test.stopTest() flushes the event bus synchronously, so any
        // assertion placed AFTER stopTest() will see both published events.
        Test.startTest();
            Database.SaveResult sr1 = EventBus.publish(event1);
            Database.SaveResult sr2 = EventBus.publish(event2);
        Test.stopTest();

        // ── Assert ────────────────────────────────────────────────────────────
        // Verify both publish operations succeeded individually.
        System.assert(sr1.isSuccess(), 'Event 1 should have published successfully.');
        System.assert(sr2.isSuccess(), 'Event 2 should have published successfully.');

        // LINE 38 FIX: assert the total number of published events equals 2.
        // Replace the List below with your actual capture mechanism if your
        // code collects events in a static list or via a trigger handler.
        List<BD_My_Platform_Event__e> publishedEvents =
            BD_PlatformEventUtility.getPublishedEvents(); // your utility method

        System.assertEquals(
            2,
            publishedEvents.size(),
            'Expected exactly 2 platform events to be published.'
        );
    }

    /**
     * Negative test — verifies that no events are published when the
     * utility is called with invalid / empty input.
     */
    @IsTest
    static void testEventUtility_NoEvents() {
        Test.startTest();
            // Call the utility with a condition that should NOT publish events.
            BD_PlatformEventUtility.processRecords(new List<SObject>());
        Test.stopTest();

        List<BD_My_Platform_Event__e> publishedEvents =
            BD_PlatformEventUtility.getPublishedEvents();

        System.assertEquals(
            0,
            publishedEvents.size(),
            'No events should be published for empty input.'
        );
    }
}
