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
            
            // Schedule password generation after scratch org is created
            // Use a future method to handle the async process
            generatePasswordAsync(scratchOrg.Id, alias);
            
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
     * Future method to generate password for scratch org after it's created
     * @param scratchOrgId The ID of the scratch org
     * @param alias The alias of the scratch org
     */
    @future(callout=true)
    public static void generatePasswordAsync(String scratchOrgId, String alias) {
        // Simplified - just mark that we attempted password generation
        try {
            ScratchOrgInfo scratchOrg = [SELECT Id, Description FROM ScratchOrgInfo WHERE Id = :scratchOrgId LIMIT 1];
            
            Map<String, Object> config = new Map<String, Object>();
            if (String.isNotBlank(scratchOrg.Description)) {
                try {
                    config = (Map<String, Object>) JSON.deserializeUntyped(scratchOrg.Description);
                } catch (Exception e) {
                    config = new Map<String, Object>();
                }
            }
            
            config.put('passwordGenerationAttempted', true);
            config.put('passwordAttemptedAt', System.now().format());
            
            scratchOrg.Description = JSON.serialize(config);
            update scratchOrg;
            
        } catch (Exception e) {
            System.debug('Error in password generation attempt: ' + e.getMessage());
        }
    }
    
    /**
     * Generates a random password for scratch org
     * @return String random password
     */
    private static String generateRandomPassword() {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        String password = '';
        
        for (Integer i = 0; i < 12; i++) {
            Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            password += chars.substring(randomIndex, randomIndex + 1);
        }
        
        password += '!@';
        return password;
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
     * Gets fresh CLI auth command by calling Salesforce APIs to get fresh token
     * @param scratchOrgId The ID of the scratch org
     * @return String The CLI command with fresh access token
     */
    @AuraEnabled
    public static String getFreshCliCommand(String scratchOrgId) {
        try {
            System.debug('getFreshCliCommand called with scratchOrgId: ' + scratchOrgId);
            
            ScratchOrgInfo scratchOrg = [
                SELECT Id, OrgName, LoginUrl, AuthCode, Status, Username, SignupUsername, Description
                FROM ScratchOrgInfo 
                WHERE Id = :scratchOrgId AND CreatedById = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            System.debug('ScratchOrgInfo record found: ' + scratchOrg.OrgName);
            
            // Try to get fresh access token using REST API callout
            String freshToken = getFreshAccessTokenViaAPI(scratchOrg);
            
            if (String.isNotBlank(freshToken)) {
                // Build the working CLI command with fresh token
                String command = 'sfdx force:auth:accesstoken:store --instanceurl ' + 
                               scratchOrg.LoginUrl + 
                               ' --accesstoken ' + freshToken + 
                               ' --setalias ' + scratchOrg.OrgName;
                
                String instructions = '# FRESH ACCESS TOKEN GENERATED!\n\n';
                instructions += '## STEP 1: Authenticate with fresh token\n';
                instructions += command + '\n\n';
                instructions += '## STEP 2: Generate password\n';
                instructions += 'sfdx force:user:password:generate -u ' + scratchOrg.OrgName + '\n\n';
                instructions += '## STEP 3: Get credentials\n';
                instructions += 'sfdx force:org:display -u ' + scratchOrg.OrgName + '\n\n';
                instructions += '## STEP 4: Open org\n';
                instructions += 'sf org open --target-org ' + scratchOrg.OrgName + '\n\n';
                instructions += '## Fresh token generated at: ' + System.now().format();
                
                return instructions;
            } else {
                // Fallback to web login if we can't get fresh token
                return buildWebLoginFallback(scratchOrg);
            }
            
        } catch (Exception e) {
            System.debug('Error in getFreshCliCommand: ' + e.getMessage());
            // Fallback to web login instructions
            ScratchOrgInfo scratchOrg = [
                SELECT Id, OrgName, LoginUrl FROM ScratchOrgInfo 
                WHERE Id = :scratchOrgId LIMIT 1
            ];
            return buildWebLoginFallback(scratchOrg);
        }
    }
    
    /**
     * Attempts to get fresh access token via Salesforce REST API
     * @param scratchOrg The scratch org info
     * @return String fresh access token or null
     */
    private static String getFreshAccessTokenViaAPI(ScratchOrgInfo scratchOrg) {
        try {
            // Make a callout to the Tooling API to get fresh scratch org info
            // This simulates what 'sfdx force:org:display --json' does
            
            String endpoint = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/tooling/sobjects/ScratchOrgInfo/' + scratchOrg.Id;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('API Response: ' + res.getBody());
            System.debug('Status Code: ' + res.getStatusCode());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String authCode = (String) responseData.get('AuthCode');
                
                System.debug('Fresh AuthCode from API: ' + (authCode != null ? 'Retrieved' : 'Null'));
                
                // The AuthCode from the API should be fresher than what's in the cached record
                return authCode;
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug('Error getting fresh token via API: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Builds fallback web login instructions
     * @param scratchOrg The scratch org info
     * @return String web login instructions
     */
    private static String buildWebLoginFallback(ScratchOrgInfo scratchOrg) {
        String instructions = '# FRESH TOKEN ACCESS (Web Login Method)\n\n';
        instructions += '## STEP 1: Authenticate via web browser\n';
        instructions += 'sf org login web --instance-url ' + scratchOrg.LoginUrl + ' --alias ' + scratchOrg.OrgName + '\n\n';
        instructions += '## STEP 2: Generate password\n';
        instructions += 'sfdx force:user:password:generate -u ' + scratchOrg.OrgName + '\n\n';
        instructions += '## STEP 3: Get credentials\n';
        instructions += 'sfdx force:org:display -u ' + scratchOrg.OrgName + '\n\n';
        instructions += '## STEP 4: Open org\n';
        instructions += 'sf org open --target-org ' + scratchOrg.OrgName + '\n\n';
        instructions += '## NOTE: Web login generates fresh tokens automatically';
        
        return instructions;
    }
    
    /**
     * Generates a password and stores it in the scratch org description
     * @param scratchOrg The scratch org info
     * @return String the generated password
     */
    private static String generateAndStorePassword(ScratchOrgInfo scratchOrg) {
        try {
            // Check if we already have a password stored
            String existingPassword = getStoredPassword(scratchOrg.Description);
            
            if (String.isNotBlank(existingPassword)) {
                System.debug('Using existing stored password');
                return existingPassword;
            }
            
            // Generate a new password
            String newPassword = generateRandomPassword();
            System.debug('Generated new password');
            
            // Store it in the Description field as JSON
            Map<String, Object> config = new Map<String, Object>();
            
            // Parse existing description if it exists
            if (String.isNotBlank(scratchOrg.Description)) {
                try {
                    config = (Map<String, Object>) JSON.deserializeUntyped(scratchOrg.Description);
                } catch (Exception e) {
                    System.debug('Could not parse existing description, starting fresh');
                    config = new Map<String, Object>();
                }
            }
            
            // Add password and username info
            config.put('adminPassword', newPassword);
            config.put('passwordGenerated', true);
            config.put('passwordGeneratedAt', System.now().format());
            config.put('storedUsername', scratchOrg.Username);
            config.put('storedSignupUsername', scratchOrg.SignupUsername);
            config.put('orgName', scratchOrg.OrgName);
            config.put('loginUrl', scratchOrg.LoginUrl);
            
            // Debug info
            System.debug('Storing username: ' + scratchOrg.Username);
            System.debug('Storing signup username: ' + scratchOrg.SignupUsername);
            
            // Update the record
            ScratchOrgInfo updateRecord = new ScratchOrgInfo(Id = scratchOrg.Id);
            updateRecord.Description = JSON.serialize(config);
            update updateRecord;
            
            System.debug('Password and username info stored in Description field');
            return newPassword;
            
        } catch (Exception e) {
            System.debug('Error generating and storing password: ' + e.getMessage());
            return generateRandomPassword(); // Return a password even if storage fails
        }
    }
    
    /**
     * Gets stored password from description field
     * @param description The description JSON
     * @return String stored password or null
     */
    private static String getStoredPassword(String description) {
        if (String.isBlank(description)) {
            return null;
        }
        
        try {
            Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(description);
            return (String) config.get('adminPassword');
        } catch (Exception e) {
            System.debug('Could not parse description for password: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Builds instructions that include password and CLI commands
     * @param scratchOrg The scratch org info
     * @param password The generated password
     * @return String comprehensive instructions
     */
    private static String buildPasswordInstructions(ScratchOrgInfo scratchOrg, String password) {
        String instructions = '# SCRATCH ORG CREDENTIALS & CLI SETUP\n\n';
        
        instructions += '## WEB LOGIN (Browser):\n';
        instructions += 'URL: ' + scratchOrg.LoginUrl + '\n';
        
        // Show all available usernames for debugging
        instructions += 'Username (field): ' + (scratchOrg.Username != null ? scratchOrg.Username : 'NULL') + '\n';
        instructions += 'SignupUsername (field): ' + (scratchOrg.SignupUsername != null ? scratchOrg.SignupUsername : 'NULL') + '\n';
        
        // Determine best username to use
        String usernameToUse = scratchOrg.Username;
        if (String.isBlank(usernameToUse)) {
            usernameToUse = scratchOrg.SignupUsername;
        }
        if (String.isBlank(usernameToUse)) {
            usernameToUse = 'USERNAME_NOT_YET_AVAILABLE';
        }
        
        instructions += 'RECOMMENDED USERNAME: ' + usernameToUse + '\n';
        instructions += 'Password: ' + password + '\n\n';
        
        instructions += '## CLI SETUP (Terminal):\n';
        instructions += '# First, authenticate via web (opens browser):\n';
        instructions += 'sf org login web --instance-url ' + scratchOrg.LoginUrl + ' --alias ' + scratchOrg.OrgName + '\n\n';
        
        instructions += '# Then open org for development:\n';
        instructions += 'sf org open --target-org ' + scratchOrg.OrgName + '\n\n';
        
        instructions += '## DEBUGGING INFO:\n';
        instructions += '- All username variants shown above\n';
        instructions += '- Try the recommended username first\n';
        instructions += '- If login fails, the scratch org may still be provisioning\n';
        instructions += '- Wait 2-3 minutes and try "Show Password" again for updated username';
        
        return instructions;
    }
    
    /**
     * Gets stored credentials for a scratch org from description field
     * @param scratchOrgId The ID of the scratch org
     * @return Map containing username and password
     */
    @AuraEnabled
    public static Map<String, String> getStoredCredentials(String scratchOrgId) {
        try {
            ScratchOrgInfo scratchOrg = [
                SELECT Id, OrgName, LoginUrl, Username, SignupUsername, Description
                FROM ScratchOrgInfo 
                WHERE Id = :scratchOrgId AND CreatedById = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            Map<String, String> credentials = new Map<String, String>();
            credentials.put('orgName', scratchOrg.OrgName);
            credentials.put('loginUrl', scratchOrg.LoginUrl);
            credentials.put('fieldUsername', scratchOrg.Username); // Username from field
            credentials.put('fieldSignupUsername', scratchOrg.SignupUsername); // SignupUsername from field
            
            // Show CLI commands to get the real password
            String cliInstructions = 'To get the REAL scratch org password:\n\n';
            cliInstructions += '1. sfdx force:auth:accesstoken:store --instanceurl ' + scratchOrg.LoginUrl + ' --accesstoken [AUTH_CODE] --setalias ' + scratchOrg.OrgName + '\n\n';
            cliInstructions += '2. sfdx force:user:password:generate -u ' + scratchOrg.OrgName + '\n\n';
            cliInstructions += '3. sfdx force:org:display -u ' + scratchOrg.OrgName + '\n\n';
            cliInstructions += 'The final command will show the real username and password.';
            
            credentials.put('password', 'Use CLI commands to generate real password');
            credentials.put('cliInstructions', cliInstructions);
            credentials.put('hasPassword', 'false'); // No fake password
            
            // Determine which username to use
            String usernameToUse = String.isNotBlank(scratchOrg.Username) ? scratchOrg.Username : scratchOrg.SignupUsername;
            if (String.isBlank(usernameToUse)) {
                usernameToUse = 'USERNAME_NOT_YET_AVAILABLE';
            }
            credentials.put('username', usernameToUse);
            
            System.debug('Field Username: ' + scratchOrg.Username);
            System.debug('Field SignupUsername: ' + scratchOrg.SignupUsername);
            System.debug('Final Username to use: ' + usernameToUse);
            
            return credentials;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting stored credentials: ' + e.getMessage());
        }
    }
    
    /**
     * Gets all stored info from description field
     * @param description The description JSON
     * @return Map<String, Object> stored info or empty map
     */
    private static Map<String, Object> getStoredInfo(String description) {
        if (String.isBlank(description)) {
            return new Map<String, Object>();
        }
        
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(description);
        } catch (Exception e) {
            System.debug('Could not parse description: ' + e.getMessage());
            return new Map<String, Object>();
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