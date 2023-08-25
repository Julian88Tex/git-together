/**
* The VariablesDatatypesOperatorsTest class is used to test the methods in the VariablesDatatypesOperators class.
* It contains individual test methods for each method in the class, validating their functionality and expected outcomes.
* The test methods utilize the Salesforce Assert class to assert and validate the results.
 * The main purpose of this test class is to ensure the accuracy and correctness of the methods in the VariablesDatatypesOperators class.
*/

@IsTest
public class VariablesDatatypesOperatorsTest {
    @IsTest
    static void testAddition() {
        Integer result = VariablesDatatypesOperators.addition(2, 3);
        Assert.areEqual(5, result, 'Incorrect addition result');
        result = VariablesDatatypesOperators.addition(-5, 10);
        Assert.areEqual(5, result, 'Incorrect negative addition result');
        result = VariablesDatatypesOperators.addition(0, 7);
        Assert.areEqual(7, result, 'Incorrect addition with 0 result');
        result = VariablesDatatypesOperators.addition(1000000, 999999);
        Assert.areEqual(1999999, result, 'Incorrect large number addition result');
        result = VariablesDatatypesOperators.addition(null, 5);
        Assert.areEqual(null, result, 'Incorrect null addition result');
    }

    @IsTest
    static void testSubtraction() {
        Integer result = VariablesDatatypesOperators.subtraction(10, 3);
        Assert.areEqual(5, result, 'Incorrect subtraction result');

        result = VariablesDatatypesOperators.subtraction(-5, -10);
        Assert.areEqual(5, result, 'Incorrect negative subtraction result');
    }

    @IsTest
    static void testMultiplication() {
        Integer result = VariablesDatatypesOperators.multiplication(5, 5);
        Assert.areEqual(25, result, 'Incorrect multiplication result');

        result = VariablesDatatypesOperators.multiplication(-5, 5);
        Assert.areEqual(-25, result, 'Incorrect negative multiplication result');
    }

    @IsTest
    static void testDivision() {
        Decimal result = VariablesDatatypesOperators.division(10, 5);
        Assert.areEqual(2, result, 'Incorrect division result');

        result = VariablesDatatypesOperators.division(10, 0);
        Assert.areEqual(0, result, 'Incorrect division by zero result');
    }

    @IsTest
    static void testIsEven() {
        Boolean result = VariablesDatatypesOperators.isEven(10);
        Assert.areEqual(true, result, 'Incorrect isEven result');

        result = VariablesDatatypesOperators.isEven(9);
        Assert.areEqual(false, result, 'Incorrect isEven result');
    }

    @IsTest
    static void testIsPositive() {
        Boolean result = VariablesDatatypesOperators.isPositive(10);
        Assert.areEqual(true, result, 'Incorrect isPositive result');

        result = VariablesDatatypesOperators.isPositive(-10);
        Assert.areEqual(false, result, 'Incorrect isPositive result');
    }

    @IsTest
    static void testConcatenateStrings() {
        String result = VariablesDatatypesOperators.concatenateStrings('Hello', 'World');
        Assert.areEqual('HelloWorld', result, 'Incorrect concatenateStrings result');
        result = VariablesDatatypesOperators.concatenateStrings('Hello', 'Cloud');
        Assert.areEqual('HelloCloud', result, 'Incorrect concatenateStrings result');
    }

    @IsTest
    static void testCombineStrings() {
        String result = VariablesDatatypesOperators.combineStrings('Hello', 'World', '!');
        Assert.areEqual('#Hello CodeWorld!!', result, 'Incorrect combineStrings result');
        result = VariablesDatatypesOperators.combineStrings('Hello', 'Cloud', '');
        Assert.areEqual('#Hello CodeCloud!', result, 'Incorrect combineStrings result');
        result = VariablesDatatypesOperators.combineStrings('I', '♥', '');
        Assert.areEqual('#I Code♥!', result, 'Incorrect combineStrings result');
    }

    @IsTest
    static void testIsDateInPast() {
        Boolean result = VariablesDatatypesOperators.isDateInPast(Date.today().addDays(-1));
        Assert.areEqual(true, result, 'Incorrect isDateInPast result');

        result = VariablesDatatypesOperators.isDateInPast(Date.today().addDays(1));
        Assert.areEqual(false, result, 'Incorrect isDateInPast result');
    }

    @IsTest
    static void testConvertMinutesToMilliseconds() {
        Integer result = VariablesDatatypesOperators.convertMinutesToMilliseconds(1);
        Assert.areEqual(60000, result, 'Incorrect convertMinutesToMilliseconds result');
    }

    @IsTest
    static void testIsDateTodayOrFuture() {
        Boolean result = VariablesDatatypesOperators.isDateTodayOrFuture(Date.today().addDays(1));
        Assert.areEqual(true, result, 'Incorrect isDateTodayOrFuture result');

        result = VariablesDatatypesOperators.isDateTodayOrFuture(Date.today().addDays(-1));
        Assert.areEqual(false, result, 'Incorrect isDateTodayOrFuture result');
    }

    @IsTest
    static void testAverageOfThreeNumbers() {
        Double result = VariablesDatatypesOperators.averageOfThreeNumbers(1, 2, 3);
        Assert.areEqual(2.0, result, 'Incorrect averageOfThreeNumbers result');
    }

    @IsTest
    static void testAdjustOrderOfOperations1() {
        Assert.areEqual(36, VariablesDatatypesOperators.adjustOrderOfOperations1(5, 7, 3), 'Incorrect result for adjustOrderOfOperations1 with 5, 7, 3 as arguments');
        Assert.areEqual(-8, VariablesDatatypesOperators.adjustOrderOfOperations1(-3, 1, 4), 'Incorrect result for adjustOrderOfOperations1 with -3, 1, 4 as arguments');
        Assert.areEqual(0, VariablesDatatypesOperators.adjustOrderOfOperations1(0, 0, 0), 'Incorrect result for adjustOrderOfOperations1 with 0, 0, 0 as arguments');
    }

    @IsTest
    static void testAdjustOrderOfOperations2() {
        Assert.areEqual(8, VariablesDatatypesOperators.adjustOrderOfOperations2(), 'Incorrect result for adjustOrderOfOperations2');
        Assert.areNotEqual(43, VariablesDatatypesOperators.adjustOrderOfOperations2(), 'Incorrect result for adjustOrderOfOperations2');
    }

    @IsTest
    static void testComplexOrderOfOperations() {
        Assert.areEqual(8.0, VariablesDatatypesOperators.complexOrderOfOperations(4, 2, 2, 2, 5), 'Incorrect result for complexOrderOfOperations with 4, 2, 2, 2, 5 as arguments');
        Assert.areEqual(5.0, VariablesDatatypesOperators.complexOrderOfOperations(3, 3, 3, 3, 3), 'Incorrect result for complexOrderOfOperations with 3, 3, 3, 3, 3 as arguments');
    }

    @IsTest
    static void testConvertFahrenheitToCelsius() {
        Assert.areEqual((Double)100.0, VariablesDatatypesOperators.convertFahrenheitToCelsius((Double)212.0), 'Incorrect conversion from 212 Fahrenheit to Celsius');
        Assert.areEqual((Double)0.0, VariablesDatatypesOperators.convertFahrenheitToCelsius((Double)32.0), 'Incorrect conversion from 32 Fahrenheit to Celsius');
        Assert.areEqual((Double)-17.8, Decimal.valueOf(VariablesDatatypesOperators.convertFahrenheitToCelsius((Double)0.0)).setScale(1), 'Incorrect conversion from 0 Fahrenheit to Celsius');
    }

    @IsTest
    static void testperformDivisionAndCast() {
        Assert.areEqual(2, VariablesDatatypesOperators.performDivisionAndCast((Double)5.0, (Double)2.0), 'Incorrect division result when rounding down is correct');
        Assert.areEqual(2, VariablesDatatypesOperators.performDivisionAndCast((Double)5.5, (Double)2.0), 'Incorrect division result when rounding up is correct');
        Assert.areEqual(2, VariablesDatatypesOperators.performDivisionAndCast((Double)4.0, (Double)2.0), 'Incorrect division result when exact division is performed');
    }

    @IsTest
    static void testCalculateWeeklyPaycheck() {
        Assert.areEqual(400.0, VariablesDatatypesOperators.calculateWeeklyPaycheck(40.0, (Double)10.0), 'Incorrect weekly paycheck for 40.0 rate and 10.0 hours');
        Assert.areEqual(0.0, VariablesDatatypesOperators.calculateWeeklyPaycheck(0.0, (Double)10.0), 'Incorrect weekly paycheck for 0.0 rate and 10.0 hours');
    }

    @IsTest
    static void testCalculateMonthlyPaycheck() {
        Assert.areEqual(1600.0, VariablesDatatypesOperators.calculateMonthlyPaycheck(40.0, (Double)10.0), 'Incorrect monthly paycheck for 40.0 rate and 10.0 hours');
        Assert.areEqual(0.0, VariablesDatatypesOperators.calculateMonthlyPaycheck(0.0, (Double)10.0), 'Incorrect monthly paycheck for 0.0 rate and 10.0 hours');
    }

    @IsTest
    static void testCalculateTotalCost() {
        Decimal result = VariablesDatatypesOperators.calculateTotalCost(10, 2, 0.1);
        Assert.areEqual(22.0, result, 'Incorrect calculateTotalCost result');
    }
}
