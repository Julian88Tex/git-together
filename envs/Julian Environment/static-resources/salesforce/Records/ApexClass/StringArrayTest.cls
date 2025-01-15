public class StringArrayTest {

    public static List<String> generateStringArray(Integer testNumber) {
        
        List<String> myList = new List<String>();
        
        for (Integer i = 0; i < testNumber ; i++) {
            myList.add('Test ' + i);
        }
        
    return myList;
        
    }
    
}