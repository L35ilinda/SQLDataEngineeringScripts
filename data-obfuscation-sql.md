## Obfuscating your SQL Server Data
If you are required to use real production data to test applications, any sensitive data should be "disguised" before loading it into the development environment. Although there are tools to generate convincing test data, it occasionally happens that the variances and frequencies within data cannot easily be simulated. In such cases, the DBA should apply one or more of the obfuscation techniques described in this article, extracted from John Magnabosco's excellent new book, Protecting SQL Server Data.

Halloween is one of my favorite times of the year. On this holiday, the young and young at heart apply make-up, masks, costumes and outfits and wander the streets in search of sweet treats from their neighbors. These costumes are designed to hide the identity of their wearer and grant that person the freedom to shed their everyday demeanor and temporarily adopt the persona of their disguise.

Applying the technique of obfuscation to our sensitive data is somewhat akin to donning a Halloween disguise. By doing so, we mask the underlying data values, hiding their true nature, until the appropriate time to disclose it.

We will explore a handful of obfuscation techniques, which do not require an algorithm, encryption key, decryption key or transformation of data types.

Each of these methods, including character scrambling and masking, numeric variance and nulling, rely on an array of built-in SQL Server system functions that are used for string manipulation.

While these methods of obfuscation will not be used by any federal government to protect nuclear missile launch codes, they can be highly effective when printing documents that contain sensitive data, transferring production data to test environments or presenting data through reporting and warehousing mechanisms.

## Development Environment Considerations
Before we proceed with an exploration of obfuscation methods, let’s spend a few moments reviewing a strong candidate for the implementation of the obfuscation methods presented in this article: the development environment.

The database that is utilized for daily business transactions is referred to as the production database. The version of the database that is used to develop and test new functionality is referred to as the development database. These environments are separated so that new development and troubleshooting can occur without having a negative effect on the performance and integrity of the production database.

Any proposed modifications to a production database should be first implemented and tested on a development or test database. In order to ensure the accuracy of this testing, the development database should mimic the production database as closely as possible, in terms of the data it contains and the set of security features it implements.

This means that all of the sensitive data efforts and options noted in this book apply to both environments and that it may be necessary to store sensitive data in both the development and production databases. The difficulty with this is that it is common for developers and testers to be granted elevated permissions within the development database. If the development database contains identical data to that stored in the production database, then these elevated permissions could present a severe and intolerable security risk to the organization and its customers.

In order to mitigate this risk, the Database Administrator responsible for refreshing the contents of the development environment should apply obfuscation methods to hide the actual values that are gleaned from the production environment.

## Obfuscation Methods
The word obfuscation is defined by the American Heritage Dictionary as follows:

“To make so confused or opaque as to be difficult to perceive or understand … to render indistinct or dim; darken.”

The word obfuscation, at times, can be used interchangeably with the term obscurity, meaning “the quality or condition of being unknown“. However, there is a subtle difference between the two terms and the former definition is more appropriate since obscurity implies that the hidden condition can be achieved without any additional effort.

Many methods of “disguise”, or obfuscation, are available to the Database Administrator that can contribute a level of control to how sensitive data is stored and disclosed, in both production and development environments. The options that will be discussed in this article are:

- Character Scrambling
- Repeating Character Masking
- Numeric Variance
- Nulling
- Artificial Data Generation
- Truncating
- Encoding
- Aggregating.

Many of these methods rely on SQL Server’s built-in system functions for string manipulation, such as SUBSTRING, REPLACE, and REPLICATE. Appendix A of my book provides a syntax reference for these, and other system functions that are useful in obfuscating sensitive data.

Prior to diving into the details of these obfuscation methods we need to explore the unique value of another system function, called RAND.

The Value of RAND
The RAND system function is not one that directly manipulates values for the benefit of obfuscation, but its ability to produce a reasonably random value makes it a valuable asset when implementing character scrambling or producing a numeric variance.

One special consideration of the RAND system function is that when it is included in a user defined function an error will be returned when the user defined function is created.

This can be overcome by creating a view that contains the RAND system function and referencing the view in the user defined function. The script in Listing 8-1 will create a view in the HomeLending database that returns a random value, using the RAND system function. Since this view holds no security threat, we will make this available to the Sensitive_high, Sensitive_medium and Sensitive_low database roles with SELECT permissions on this view.

STEP 1
```
Use HomeLending;
GO
 
-- Used to reference RAND with in a function
CREATE VIEW dbo.vwRandom
AS
SELECT RAND() as RandomValue;
GO
 
-- Grant permissions to view
GRANT SELECT ON dbo.vwRandom
    TO Sensitive_high, Sensitive_medium, Sensitive_low;
GO
```

STEP 2

```
DECLARE @Rand float;
DECLARE @MinVal int;
DECLARE @MaxVal int;
SET @MinVal = 1;="color:black">
SET @MaxVal = 100;="color:black">
 
SELECT
     @Rand = ((@MinVal + 1) - @MaxVal) * RandomValue + @MaxVal
FROM
     dbo.vwRandom
GO
```

STEP 3

```
Use HomeLending;
GO
 
-- Create user defined function
CREATE FUNCTION Character_Scramble =
(
    @OrigVal varchar(max)
)
RETURNS varchar(max)
WITH ENCRYPTION
AS
BEGIN
 
-- Variables used
DECLARE @NewVal varchar(max);
DECLARE @OrigLen int;
DECLARE @CurrLen int;
DECLARE @LoopCt int;
DECLARE @Rand int;
 
-- Set variable default values
SET @NewVal = '';
SET @OrigLen = DATALENGTH(@OrigVal);
SET @CurrLen = @OrigLen;
SET @LoopCt = 1;
 
-- Loop through the characters passed
WHILE @LoopCt <= @OrigLen
    BEGIN
        -- Current length of possible characters
        SET @CurrLen = DATALENGTH(@OrigVal);
 
        -- Random position of character to use
        SELECT
            @Rand = Convert(int,(((1) - @CurrLen) *
                               RandomValue + @CurrLen))
        FROM
            dbo.vwRandom;
 
        -- Assembles the value to be returned
        SET @NewVal = @NewVal +
                             SUBSTRING(@OrigVal,@Rand,1);
 
        -- Removes the character from available options
        SET @OrigVal =
                 Replace(@OrigVal,SUBSTRING(@OrigVal,@Rand,1),'');
 
        -- Advance the loop="color:black">
        SET @LoopCt = @LoopCt + 1;
    END
    -- Returns new value
    Return LOWER(@NewVal);
END
GO
 
-- Grant permissions to user defined function
GRANT EXECUTE ON dbo.Character_Scramble
    TO Sensitive_high, Sensitive_medium, Sensitive_low;
GO
```

STEP 4

```
Use HomeLending;
GO
 
-- Create user defined function
CREATE FUNCTION Character_Mask
(
    @OrigVal varchar(max),
    @InPlain int,
    @MaskChar char(1)
)
RETURNS varchar(max)
WITH ENCRYPTION
AS
BEGIN
 
    -- Variables used
    DECLARE @PlainVal varchar(max);
    DECLARE @MaskVal varchar(max);
    DECLARE @MaskLen int;
 
    -- Captures the portion of @OrigVal that remains in plain text
    SET @PlainVal = RIGHT(@OrigVal,@InPlain);
    -- Defines the length of the repeating value for the mask
    SET @MaskLen = (DATALENGTH(@OrigVal) - @InPlain);
    -- Captures the mask value
    SET @MaskVal = REPLICATE(@MaskChar, @MaskLen);
    -- Returns the masked value
    Return @MaskVal + @PlainVal;
 
END
GO
 
-- Grant permissions to user defined function
GRANT EXECUTE ON dbo.Character_Mask
    TO Sensitive_high, Sensitive_medium, Sensitive_low;
GO
```

STEP 5

```
Use HomeLending;
GO
 
CREATE VIEW dbo.vwLoanBorrowers
AS
SELECT
    dbo.Character_Mask(ln.Lender_Case_Number,4,'X')
        AS Lender_Case_Number,
    dbo.Character_Scramble(bn.Borrower_FName + ' '
        + bn.Borrower_LName)
        AS Borrower_Name
FROM
    dbo.Loan ln
    INNER JOIN dbo.Loan_Borrowers lb
        ON ln.Loan_ID = lb.Loan_ID
        AND lb.Borrower_Type_ID = 1 -- Primary Borrowers Only
    INNER JOIN dbo.Borrower_Name bn
        ON lb.Borrower_ID = bn.Borrower_ID;
GO
 
-- Grant permissions to view
GRANT SELECT ON dbo.vwLoanBorrowers
    TO Sensitive_high, Sensitive_medium;
GO
```

STEP 6

```
USE HomeLending;
GO
 
-- Create user defined function
CREATE FUNCTION Numeric_Variance
(
    @OrigVal float,
    @VarPercent numeric(5,2)
)
RETURNS float
WITH ENCRYPTION
AS
BEGIN
    -- Variable used
    DECLARE @Rand int;
 
    -- Random position of character to use
    SELECT
        @Rand = Convert(int,((((0-@VarPercent)+1) -
               @VarPercent) * RandomValue + @VarPercent))
    FROM
        dbo.vwRandom;
 
    RETURN @OrigVal + CONVERT(INT,((@OrigVal*@Rand)/100));
END
GO
 
-- Grant permissions to user defined function
GRANT EXECUTE ON dbo.Numeric_Variance
    TO Sensitive_high, Sensitive_medium, Sensitive_low;
GO
```

STEP 7
```
USE HomeLending;
GO
 
-- Variables used
DECLARE @Variance numeric(5,2)
-- Set variance to 10%
SET @Variance = 10
 
UPDATE dbo.Loan_Term
    SET Loan_Amount =
            dbo.Numeric_Variance(Loan_Amount,@Variance)
FROM
    dbo.Loan_Term;
GO
```




