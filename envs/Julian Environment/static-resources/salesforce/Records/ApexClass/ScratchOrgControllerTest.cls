/**
 * Test class for ScratchOrgController
 * Tests the core scratch org creation functionality
 */
@isTest
public class ScratchOrgControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test data if needed
    }
    
    @isTest
    static void testCreateScratchOrg_Success() {
        Test.startTest();
        
        String result = ScratchOrgController.createScratchOrg(
            'test-scratch-org', 
            7, 
            '{"orgName": "Test Org", "edition": "Developer"}'
        );
        
        Test.stopTest();
        
        // Verify scratch org was created
        System.assertNotEquals(null, result, 'Scratch org ID should be returned');
        
        // Verify the record exists
        List<ScratchOrgInfo> scratchOrgs = [
            SELECT Id, OrgName, DurationDays, Edition, Description 
            FROM ScratchOrgInfo 
            WHERE Id = :result
        ];
        
        System.assertEquals(1, scratchOrgs.size(), 'One scratch org should be created');
        System.assertEquals('test-scratch-org', scratchOrgs[0].OrgName, 'Org name should match');
        System.assertEquals(7, scratchOrgs[0].DurationDays, 'Duration should match');
        System.assertEquals('Developer', scratchOrgs[0].Edition, 'Edition should be set');
    }
    
    @isTest
    static void testCreateScratchOrg_InvalidAlias() {
        Test.startTest();
        
        try {
            ScratchOrgController.createScratchOrg('', 7, '{}');
            System.assert(false, 'Exception should be thrown for empty alias');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Alias is required'), 'Should validate alias');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreateScratchOrg_InvalidDuration() {
        Test.startTest();
        
        try {
            ScratchOrgController.createScratchOrg('test-org', 35, '{}');
            System.assert(false, 'Exception should be thrown for invalid duration');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Duration must be between'), 'Should validate duration');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetScratchOrgs() {
        // Create test scratch org
        ScratchOrgInfo testOrg = new ScratchOrgInfo();
        testOrg.OrgName = 'test-org';
        testOrg.DurationDays = 7;
        testOrg.Edition = 'Developer';
        insert testOrg;
        
        Test.startTest();
        
        List<ScratchOrgInfo> result = ScratchOrgController.getScratchOrgs();
        
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should return one scratch org');
        System.assertEquals('test-org', result[0].OrgName, 'Should match test org');
    }
    
    @isTest
    static void testDeleteScratchOrg() {
        // Create test scratch org
        ScratchOrgInfo testOrg = new ScratchOrgInfo();
        testOrg.OrgName = 'test-org';
        testOrg.DurationDays = 7;
        testOrg.Edition = 'Developer';
        insert testOrg;
        
        Test.startTest();
        
        Boolean result = ScratchOrgController.deleteScratchOrg(testOrg.Id);
        
        Test.stopTest();
        
        System.assertEquals(true, result, 'Delete should be successful');
        
        // Verify org was deleted
        List<ScratchOrgInfo> remainingOrgs = [SELECT Id FROM ScratchOrgInfo WHERE Id = :testOrg.Id];
        System.assertEquals(0, remainingOrgs.size(), 'Scratch org should be deleted');
    }
    
    @isTest
    static void testGetConfigOptions() {
        Test.startTest();
        
        List<ScratchOrgController.ConfigOption> options = ScratchOrgController.getConfigOptions();
        
        Test.stopTest();
        
        System.assert(!options.isEmpty(), 'Should return config options');
        System.assertEquals('basic', options[0].value, 'First option should be basic');
    }
}