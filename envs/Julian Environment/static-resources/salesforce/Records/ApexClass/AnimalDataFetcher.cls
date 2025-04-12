public with sharing class AnimalDataFetcher {

    // Define the endpoint URL as a constant
    private static final String ENDPOINT_URL = 'callout:MyNamedCredential/api/animal-data';

    public static void updateAnimalData() {
        List<Animal__c> animalList = new List<Animal__c>();

        //Mock response for demonstration purpose
        String mockedResponse = '[{"id": 1, "name": "Tiger", "food-category": "Carnivore", "count": 42, "park-name": "Wild Animal Safari"}, {"id": 2, "name": "Gray Wolf", "food-category": "Carnivore", "count": 120, "park-name": "Wild Animal Safari"}]';

        // Create a fake HTTP response object with the mocked response
        HttpResponse response = new HttpResponse();
        response.setBody(mockedResponse);
        response.setStatusCode(200);

        // Parse the response JSON and create Animal__c records
        List<Object> jsonResponse = (List<Object>)JSON.deserializeUntyped(response.getBody());
        for (Object obj : jsonResponse) {
            Map<String, Object> animalMap = (Map<String, Object>)obj;
            Animal__c animal = new Animal__c();
            animal.External_ID__c = String.valueOf(animalMap.get('id')); // Use the API ID as the External ID
            animal.Animal_Name__c = (String)animalMap.get('name');
            animal.Food_Category__c = (String)animalMap.get('food-category');
            animal.Count__c = (Integer)animalMap.get('count');
            animal.Park_Name__c = (String)animalMap.get('park-name');
            animalList.add(animal);
        }
        // Upsert the Animal__c records using the External ID
        Database.upsert(animalList, Animal__c.Fields.External_ID__c);
    }
}