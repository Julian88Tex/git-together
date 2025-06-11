/**
 * ScratchOrgController - Apex controller for managing scratch org creation
 * Handles the backend logic for creating scratch orgs via ScratchOrgInfo API
 */
public with sharing class ScratchOrgController {
    
    /**
     * Creates a new scratch org using the provided configuration
     * @param alias The alias for the scratch org
     * @param durationDays Number of days the scratch org should be active (1-30)
     * @param configJson JSON configuration for the scratch org
     * @return String The created scratch org ID or error message
     */
    @AuraEnabled
    public static String createScratchOrg(String alias, Integer durationDays, String configJson) {
        try {
            // Validate inputs
            if (String.isBlank(alias)) {
                throw new AuraHandledException('Alias is required');
            }
            
            if (durationDays < 1 || durationDays > 30) {
                throw new AuraHandledException('Duration must be between 1 and 30 days');
            }
            
            // Create ScratchOrgInfo record
            ScratchOrgInfo scratchOrg = new ScratchOrgInfo();
            scratchOrg.OrgName = alias;
            scratchOrg.DurationDays = durationDays;
            scratchOrg.Edition = 'Developer'; // Required field - set default edition
            
            // Try using Salesforce CLI's default connected app
            scratchOrg.ConnectedAppConsumerKey = 'PlatformCLI';
            scratchOrg.ConnectedAppCallbackUrl = 'http://localhost:1717/OauthRedirect';
            
            // Set configuration if provided
            if (String.isNotBlank(configJson)) {
                scratchOrg.Description = configJson;
                
                // Try to parse JSON and extract edition if specified
                try {
                    Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(configJson);
                    if (config.containsKey('edition')) {
                        scratchOrg.Edition = (String) config.get('edition');
                    }
                } catch (Exception jsonEx) {
                    // If JSON parsing fails, keep default edition
                    System.debug('Could not parse config JSON: ' + jsonEx.getMessage());
                }
            }
            
            insert scratchOrg;
            
            return scratchOrg.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating scratch org: ' + e.getMessage());
        }
    }
    
    /**
     * Retrieves list of existing scratch orgs for the current user
     * @return List of ScratchOrgInfo records
     */
    @AuraEnabled(cacheable=true)
    public static List<ScratchOrgInfo> getScratchOrgs() {
        try {
            return [
                SELECT Id, OrgName, Status, DurationDays, Edition, CreatedDate, ExpirationDate, 
                       Description, AuthCode, LoginUrl, Username, SignupUsername
                FROM ScratchOrgInfo 
                WHERE CreatedById = :UserInfo.getUserId()
                AND Status = 'Active'
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving scratch orgs: ' + e.getMessage());
        }
    }
    
    /**
     * Deletes a scratch org
     * @param scratchOrgId The ID of the scratch org to delete
     * @return Boolean success status
     */
    @AuraEnabled
    public static Boolean deleteScratchOrg(String scratchOrgId) {
        try {
            ScratchOrgInfo scratchOrg = [
                SELECT Id FROM ScratchOrgInfo 
                WHERE Id = :scratchOrgId AND CreatedById = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            delete scratchOrg;
            return true;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting scratch org: ' + e.getMessage());
        }
    }
    
    /**
     * Gets CLI auth command for a scratch org
     * @param scratchOrgId The ID of the scratch org
     * @return Map containing multiple auth options
     */
    @AuraEnabled
    public static Map<String, String> getCliAuthCommand(String scratchOrgId) {
        try {
            ScratchOrgInfo scratchOrg = [
                SELECT Id, OrgName, AuthCode, LoginUrl, Username
                FROM ScratchOrgInfo 
                WHERE Id = :scratchOrgId AND CreatedById = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            Map<String, String> authInfo = new Map<String, String>();
            authInfo.put('orgName', scratchOrg.OrgName);
            authInfo.put('loginUrl', scratchOrg.LoginUrl);
            authInfo.put('username', scratchOrg.Username);
            authInfo.put('authCode', scratchOrg.AuthCode);
            
            // Generate different command options
            if (String.isNotBlank(scratchOrg.AuthCode)) {
                // Try the newer CLI format
                String accessTokenCmd = 'sf org login access-token --instance-url ' + scratchOrg.LoginUrl + ' --access-token ' + scratchOrg.AuthCode + ' --alias ' + scratchOrg.OrgName;
                authInfo.put('accessTokenCommand', accessTokenCmd);
                
                // Legacy format (might still work)
                String legacyCmd = 'sfdx force:auth:accesstoken:store --instanceurl ' + scratchOrg.LoginUrl + ' --accesstoken ' + scratchOrg.AuthCode + ' --setalias ' + scratchOrg.OrgName;
                authInfo.put('legacyCommand', legacyCmd);
            }
            
            return authInfo;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting CLI auth command: ' + e.getMessage());
        }
    }
    
    /**
     * Gets available scratch org definition files
     * @return List of available config files
     */
    @AuraEnabled(cacheable=true)
    public static List<ConfigOption> getConfigOptions() {
        List<ConfigOption> options = new List<ConfigOption>();
        
        options.add(new ConfigOption('basic', 'Basic Scratch Org', 
            '{"orgName": "Basic Scratch Org", "edition": "Developer"}'));
        options.add(new ConfigOption('sales', 'Sales Cloud', 
            '{"orgName": "Sales Cloud Scratch Org", "edition": "Enterprise", "features": ["Sales"]}'));
        options.add(new ConfigOption('service', 'Service Cloud', 
            '{"orgName": "Service Cloud Scratch Org", "edition": "Enterprise", "features": ["Service"]}'));
        
        return options;
    }
    
    /**
     * Wrapper class for configuration options
     */
    public class ConfigOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String config { get; set; }
        
        public ConfigOption(String value, String label, String config) {
            this.value = value;
            this.label = label;
            this.config = config;
        }
    }
}