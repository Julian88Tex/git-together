import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import createScratchOrg from '@salesforce/apex/ScratchOrgController.createScratchOrg';
import getScratchOrgs from '@salesforce/apex/ScratchOrgController.getScratchOrgs';
import deleteScratchOrg from '@salesforce/apex/ScratchOrgController.deleteScratchOrg';
import getCliAuthCommand from '@salesforce/apex/ScratchOrgController.getCliAuthCommand';
import getConfigOptions from '@salesforce/apex/ScratchOrgController.getConfigOptions';

export default class ScratchOrgManager extends LightningElement {
    @track alias = '';
    @track durationDays = 7;
    @track selectedConfig = 'basic';
    @track customConfig = '';
    @track isLoading = false;
    @track showCustomConfig = false;
    @track showCommandModal = false;
    @track currentCommand = '';
    @track currentOrgName = '';
    
    // Data properties
    scratchOrgsResult;
    configOptions = [];
    
    // Wire methods
    @wire(getScratchOrgs)
    wiredScratchOrgs(result) {
        this.scratchOrgsResult = result;
    }
    
    @wire(getConfigOptions)
    wiredConfigOptions({ error, data }) {
        if (data) {
            this.configOptions = data.map(option => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            console.error('Error loading config options:', error);
        }
    }
    
    // Getters
    get scratchOrgs() {
        return this.scratchOrgsResult?.data || [];
    }
    
    get hasError() {
        return this.scratchOrgsResult?.error;
    }
    
    get error() {
        return this.scratchOrgsResult?.error?.body?.message || 'Unknown error';
    }
    
    get durationOptions() {
        return [
            { label: '1 day', value: 1 },
            { label: '3 days', value: 3 },
            { label: '7 days', value: 7 },
            { label: '14 days', value: 14 },
            { label: '30 days', value: 30 }
        ];
    }
    
    get isCreateDisabled() {
        return this.isLoading || !this.alias.trim();
    }
    
    get columns() {
        return [
            { 
                label: 'Org Name', 
                fieldName: 'OrgName', 
                type: 'text',
                wrapText: true
            },
            { 
                label: 'Edition', 
                fieldName: 'Edition', 
                type: 'text'
            },
            { 
                label: 'Login URL', 
                fieldName: 'LoginUrl', 
                type: 'url',
                typeAttributes: {
                    label: 'Open Org',
                    target: '_blank'
                }
            },
            { 
                label: 'Duration (Days)', 
                fieldName: 'DurationDays', 
                type: 'number'
            },
            { 
                label: 'Created', 
                fieldName: 'CreatedDate', 
                type: 'date',
                typeAttributes: {
                    year: 'numeric',
                    month: 'short',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit'
                }
            },
            { 
                label: 'Expires', 
                fieldName: 'ExpirationDate', 
                type: 'date',
                typeAttributes: {
                    year: 'numeric',
                    month: 'short',
                    day: '2-digit'
                }
            },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: '📋 Get CLI Auth Command', name: 'cli_auth' },
                        { label: '🔗 Copy Login URL', name: 'copy_url' },
                        { label: '🗑️ Delete', name: 'delete' }
                    ]
                }
            }
        ];
    }
    
    // Event handlers
    handleAliasChange(event) {
        this.alias = event.target.value;
    }
    
    handleDurationChange(event) {
        this.durationDays = parseInt(event.target.value);
    }
    
    handleConfigChange(event) {
        this.selectedConfig = event.target.value;
        this.showCustomConfig = event.target.value === 'custom';
    }
    
    handleCustomConfigChange(event) {
        this.customConfig = event.target.value;
    }
    
    async handleCreateScratchOrg() {
        if (!this.alias.trim()) {
            this.showToast('Error', 'Please enter an alias for the scratch org', 'error');
            return;
        }
        
        this.isLoading = true;
        
        try {
            let configJson = '';
            
            if (this.showCustomConfig) {
                configJson = this.customConfig;
                // Validate JSON if custom config is provided
                if (configJson.trim()) {
                    try {
                        JSON.parse(configJson);
                    } catch (e) {
                        throw new Error('Invalid JSON in custom configuration');
                    }
                }
            } else {
                // Get predefined config
                const selectedOption = this.configOptions.find(opt => opt.value === this.selectedConfig);
                if (selectedOption) {
                    configJson = selectedOption.config;
                }
            }
            
            const result = await createScratchOrg({
                alias: this.alias,
                durationDays: this.durationDays,
                configJson: configJson
            });
            
            this.showToast('Success', `Scratch org "${this.alias}" created successfully!`, 'success');
            this.resetForm();
            
            // Refresh the scratch orgs list
            return refreshApex(this.scratchOrgsResult);
            
        } catch (error) {
            console.error('Error creating scratch org:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'delete') {
            if (confirm(`Are you sure you want to delete scratch org "${row.OrgName}"?`)) {
                try {
                    await deleteScratchOrg({ scratchOrgId: row.Id });
                    this.showToast('Success', 'Scratch org deleted successfully', 'success');
                    return refreshApex(this.scratchOrgsResult);
                } catch (error) {
                    this.showToast('Error', error.body?.message || error.message, 'error');
                }
            }
        } else if (actionName === 'cli_auth') {
            try {
                const authInfo = await getCliAuthCommand({ scratchOrgId: row.Id });
                this.currentCommand = authInfo.accessTokenCommand || 'Auth info not available yet';
                this.currentOrgName = row.OrgName;
                this.showCommandModal = true;
                
                // Show comprehensive auth info
                this.showCliAuthInfo(authInfo);
            } catch (error) {
                this.showToast('Error', error.body?.message || error.message, 'error');
            }
        } else if (actionName === 'copy_url') {
            if (row.LoginUrl && navigator.clipboard) {
                navigator.clipboard.writeText(row.LoginUrl);
                this.showToast('Success', 'Login URL copied to clipboard!', 'success');
            } else {
                this.showToast('Error', 'Unable to copy URL to clipboard', 'error');
            }
        }
    }
    
    closeCommandModal() {
        this.showCommandModal = false;
        this.currentCommand = '';
        this.currentOrgName = '';
    }
    
    handleCopyCommand() {
        // Try to copy to clipboard
        if (navigator.clipboard) {
            navigator.clipboard.writeText(this.currentCommand).then(() => {
                this.showToast('Success', 'Command copied to clipboard!', 'success');
            }).catch(() => {
                this.showToast('Info', 'Please select and copy the text manually', 'info');
            });
        } else {
            // Fallback: select the text
            const textarea = this.template.querySelector('.command-text');
            if (textarea) {
                textarea.select();
                this.showToast('Info', 'Command selected - press Ctrl+C to copy', 'info');
            }
        }
    }
    
    showCliAuthInfo(authInfo) {
        let message = `🚀 CLI Authentication Options for ${authInfo.orgName}\n\n`;
        
        if (authInfo.accessTokenCommand) {
            message += `🟢 RECOMMENDED (SF CLI v2):\n${authInfo.accessTokenCommand}\n\n`;
        }
        
        if (authInfo.legacyCommand) {
            message += `🟡 LEGACY (SFDX CLI):\n${authInfo.legacyCommand}\n\n`;
        }
        
        if (authInfo.loginUrl) {
            message += `🌐 BROWSER LOGIN:\n${authInfo.loginUrl}\n\n`;
        }
        
        message += `📝 Steps:\n`;
        message += `1. Copy one of the commands above\n`;
        message += `2. Open your terminal\n`;
        message += `3. Paste and run the command\n`;
        message += `4. Start developing!\n\n`;
        message += `💡 If first command fails, try the legacy version`;
        
        // Try to copy the recommended command
        if (authInfo.accessTokenCommand && navigator.clipboard) {
            navigator.clipboard.writeText(authInfo.accessTokenCommand);
            message += `\n\n✅ Recommended command copied to clipboard!`;
        }
        
        alert(message);
    }
    
    resetForm() {
        this.alias = '';
        this.durationDays = 7;
        this.selectedConfig = 'basic';
        this.customConfig = '';
        this.showCustomConfig = false;
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}