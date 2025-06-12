import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import createScratchOrg from '@salesforce/apex/ScratchOrgController.createScratchOrg';
import getScratchOrgs from '@salesforce/apex/ScratchOrgController.getScratchOrgs';
import deleteScratchOrg from '@salesforce/apex/ScratchOrgController.deleteScratchOrg';
import getFreshCliCommand from '@salesforce/apex/ScratchOrgController.getFreshCliCommand';
import getStoredCredentials from '@salesforce/apex/ScratchOrgController.getStoredCredentials';
import getConfigOptions from '@salesforce/apex/ScratchOrgController.getConfigOptions';

export default class ScratchOrgManager extends LightningElement {
    @track alias = '';
    @track durationDays = 7;
    @track selectedConfig = 'basic';
    @track customConfig = '';
    @track isLoading = false;
    @track showCustomConfig = false;
    
    scratchOrgsResult;
    configOptions = [];
    
    @wire(getScratchOrgs)
    wiredScratchOrgs(result) {
        this.scratchOrgsResult = result;
        if (result.data) {
            console.log('Scratch orgs data:', JSON.stringify(result.data, null, 2));
        } else if (result.error) {
            console.error('Error loading scratch orgs:', result.error);
        }
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
                label: 'Username', 
                fieldName: 'Username', 
                type: 'text',
                wrapText: true
            },
            { 
                label: 'Edition', 
                fieldName: 'Edition', 
                type: 'text'
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
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: '🔑 Get Real Password Steps', name: 'get_cli_command' },
                        { label: '🗑️ Delete', name: 'delete' }
                    ]
                }
            }
        ];
    }
    
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
                if (configJson.trim()) {
                    try {
                        JSON.parse(configJson);
                    } catch (e) {
                        throw new Error('Invalid JSON in custom configuration');
                    }
                }
            } else {
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
            
            return refreshApex(this.scratchOrgsResult);
            
        } catch (error) {
            console.error('Error creating scratch org:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleRowAction(event) {
        console.log('handleRowAction called');
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
        } else if (actionName === 'get_cli_command') {
            try {
                this.showToast('Info', 'Getting CLI instructions for real password...', 'info');
                
                const cliCommand = await getFreshCliCommand({ scratchOrgId: row.Id });
                
                if (cliCommand) {
                    this.showCliCommandPopup(cliCommand, row.OrgName);
                    this.showToast('Success', 'CLI instructions ready!', 'success');
                } else {
                    this.showToast('Warning', 'No CLI instructions returned.', 'warning');
                }
                
            } catch (error) {
                console.error('Error getting CLI instructions:', error);
                this.showToast('Error', error.body?.message || error.message, 'error');
            }
        }
    }
    
    showCliCommandPopup(command, orgName) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(command).then(() => {
                console.log('Command copied to clipboard');
            }).catch(err => {
                console.log('Could not copy to clipboard:', err);
            });
        }
        
        let message = `🚀 Real Password Instructions for ${orgName}\n\n`;
        message += `${command}\n\n`;
        message += `✅ Instructions copied to clipboard!`;
        
        prompt('Copy these instructions (Ctrl+C):', command);
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