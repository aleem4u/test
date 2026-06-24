/**
 * @class       SVMX_BD_SharingRulesTest
 * @description Corrected test class for sharing rules on Product Stock.
 *
 * ROOT CAUSE:  BD_ProductStockTriggerHandler.productStockExternalId (line 346)
 *              tried to build an External ID by accessing a parent-relationship
 *              field (e.g. product.ProductCode or a Location lookup) that was
 *              null because the test-data factory did not insert those parents
 *              before inserting the ProductItem / Product Stock record.
 *
 * FIX (two-part):
 *   A) Test Data  — Insert Product2 and Location parents first; assign IDs to
 *                   the stock record before insert.
 *   B) Handler    — Add a null guard in productStockExternalId so the trigger
 *                   never NPEs on incomplete data (see patched snippet below).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * HANDLER PATCH  (BD_ProductStockTriggerHandler — around line 346)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   // BEFORE (throws NullPointerException when lookup is null):
 *   private void productStockExternalId(List<ProductItem> stocks) {
 *       for (ProductItem stock : stocks) {
 *           stock.ExternalId__c =
 *               stock.Product2.ProductCode + '-' + stock.LocationId; // NPE here
 *       }
 *   }
 *
 *   // AFTER (null-safe):
 *   private void productStockExternalId(List<ProductItem> stocks) {
 *       for (ProductItem stock : stocks) {
 *           if (stock.Product2Id != null
 *                   && stock.Product2 != null
 *                   && String.isNotBlank(stock.Product2.ProductCode)
 *                   && stock.LocationId != null) {
 *               stock.ExternalId__c =
 *                   stock.Product2.ProductCode + '-' + stock.LocationId;
 *           } else {
 *               stock.ExternalId__c = null; // or a safe default
 *           }
 *       }
 *   }
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * TEST DATA FACTORY PATCH  (SVMX_BD_TestDataFactory.createTestData — line 169)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   // BEFORE (ProductItem inserted without parent records — trigger NPEs):
 *   ProductItem stock = new ProductItem(...);
 *   insert stock;   // <-- triggers BD_ProductStockTriggerHandler → NPE
 *
 *   // AFTER:
 *   Product2 prod = new Product2(
 *       Name        = 'Test Product',
 *       ProductCode = 'TST-001',
 *       IsActive    = true
 *   );
 *   insert prod;
 *
 *   Schema.Location loc = new Schema.Location(
 *       Name             = 'Test Location',
 *       LocationType     = 'Other',
 *       IsInventoryLocation = true
 *   );
 *   insert loc;
 *
 *   ProductItem stock = new ProductItem(
 *       Product2Id  = prod.Id,   // required parent
 *       LocationId  = loc.Id,    // required parent
 *       QuantityOnHand = 10
 *   );
 *   insert stock;  // trigger now has all fields to build ExternalId safely
 */
@IsTest
private class SVMX_BD_SharingRulesTest {

    // ── Test data helpers ─────────────────────────────────────────────────────

    /**
     * Creates and inserts a Product2 parent record.
     */
    private static Product2 createProduct(String productCode) {
        Product2 prod = new Product2(
            Name        = 'Test Product ' + productCode,
            ProductCode = productCode,
            IsActive    = true
        );
        insert prod;
        return prod;
    }

    /**
     * Creates and inserts a Location parent record.
     */
    private static Schema.Location createLocation(String locName) {
        Schema.Location loc = new Schema.Location(
            Name                  = locName,
            LocationType          = 'Other',
            IsInventoryLocation   = true
        );
        insert loc;
        return loc;
    }

    /**
     * Creates and inserts a ProductItem (Product Stock) with full parent
     * linkage so the trigger handler never receives null lookups.
     */
    private static ProductItem createProductStock(Id productId, Id locationId, Decimal qty) {
        ProductItem stock = new ProductItem(
            Product2Id     = productId,
            LocationId     = locationId,
            QuantityOnHand = qty
        );
        insert stock;   // trigger fires safely — parents are already set
        return stock;
    }

    // ── Test methods ──────────────────────────────────────────────────────────

    /**
     * Verifies that sharing rules are correctly applied after inserting
     * Product Stock records with all required parent lookups in place.
     *
     * FIXES:
     *   • Product2 and Location are inserted BEFORE ProductItem (no NPE).
     *   • The trigger handler null guard prevents line-346 NPE if edge cases
     *     ever reach it.
     */
    @IsTest
    static void testSharingRules() {

        // ── Arrange ───────────────────────────────────────────────────────────
        Product2        prod  = createProduct('TST-001');
        Schema.Location loc   = createLocation('Warehouse A');

        // ── Act ───────────────────────────────────────────────────────────────
        Test.startTest();
            ProductItem stock = createProductStock(prod.Id, loc.Id, 100);
        Test.stopTest();

        // ── Assert ────────────────────────────────────────────────────────────
        // Confirm the External ID was built correctly by the trigger handler.
        ProductItem inserted = [
            SELECT Id, ExternalId__c, QuantityOnHand
            FROM   ProductItem
            WHERE  Id = :stock.Id
        ];

        System.assertEquals(
            'TST-001-' + loc.Id,
            inserted.ExternalId__c,
            'ExternalId should be ProductCode-LocationId.'
        );

        // Confirm sharing rule was applied (adjust Share object to your org).
        List<ProductItemShare> shares = [
            SELECT Id
            FROM   ProductItemShare
            WHERE  ParentId = :stock.Id
              AND  RowCause = 'Rule'
        ];
        System.assert(!shares.isEmpty(), 'At least one sharing rule record should exist.');
    }

    /**
     * Verifies that a ProductItem with a null Product2 lookup does NOT
     * cause an NPE after the handler null guard is in place.
     */
    @IsTest
    static void testSharingRules_NullProductHandledGracefully() {

        Schema.Location loc = createLocation('Warehouse B');

        // Intentionally omit Product2Id to test the null guard.
        ProductItem stockNoProd = new ProductItem(
            LocationId     = loc.Id,
            QuantityOnHand = 5
        );

        Test.startTest();
            try {
                insert stockNoProd;
                // If insert succeeds, ExternalId should be null (safe default).
                ProductItem result = [
                    SELECT ExternalId__c FROM ProductItem WHERE Id = :stockNoProd.Id
                ];
                System.assertEquals(null, result.ExternalId__c,
                    'ExternalId should be null when Product2 is missing.');
            } catch (DmlException e) {
                // A required-field validation error is acceptable here;
                // an NPE/System.NullPointerException is NOT.
                System.assert(
                    !e.getMessage().contains('NullPointerException'),
                    'Handler should never throw NPE — only expected DML errors.'
                );
            }
        Test.stopTest();
    }
}
