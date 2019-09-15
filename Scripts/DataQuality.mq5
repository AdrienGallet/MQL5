//+------------------------------------------------------------------+
//|                                                 DataQuality3.mq5 |
//|                                          Trademark 2019, PxStrat™|
//|                                        https://www.pxstrat.co.uk |
//+------------------------------------------------------------------+

/*
//+------------------------------------------------------------------+
//| Read me                                                          |
//+------------------------------------------------------------------+
The purpose of this script is to quickly establish the data quality
provided by the broker. This is achieved by analysing the number of
additional and missing data bars exist during a specific time-frame
set by the user.

//Assumptions and limitations
Trading session hours provided by broker are assumed to be typical for the entire year.
   --- Not entirely correct due to public holidays and DST changes during the year.
The script assumes that no more than 10 individual trading sessions exist each day.

Possible future updates:
--- Reconsider if Trading Session could not be improved even further, perhaps by including known public holidays.
------ Perhaps divide by trading class, etc. or allowing users to over-ride the automatic QuoteSession script.
--- Consider exporting the assumed trading hours
--- Consider checking TERMINAL MAX BARS
*/

//+------------------------------------------------------------------+
//| Program Information                                              |
//+------------------------------------------------------------------+
#property copyright "Trademark 2019, PxStrat™"
#property link      "https://www.pxstrat.co.uk/downloads/dataquality"
#property icon      "\\Files\\PxStrat Files\\LogoPxStrat.ico"
#property version   "1.0"
#property description "This script conducts and exports M1 data quality checks "
                      "on attached charts. Results can be found by referring "
                      "to the output under the \"Experts\" tab within the Toolbox."
#property description "\n"
#property description "Refer to the link Trademark 2019, PxStrat™ for details on this script, " 
                      "help and support, and other automated trading topics."
#property script_show_inputs


//+------------------------------------------------------------------+
//| Variables                                                        |
//+------------------------------------------------------------------+
//--- Input variables
input datetime startDate = D'2018.01.01 00:00:00'; //Specify the start date
input datetime endDate = D'2019.01.01 00:00:00'; //Specific the end date

//--- Script variables
ulong startTick, duration;

//--- Price data variables
MqlRates priceData[];
int availableBars=0, attempt=0;
datetime adjStartDate, adjEndDate;

//--- Session timetable variables
datetime openDT, closeDT, checkDate;
struct QuoteSessionStruct
  {
   bool quoteStatus; //True if quotes should exist
   datetime openDT;
   datetime closeDT;
  } quoteSession[7][10]; //Multi-dimensional structure for 7 weekdays and maximum 10 trading sessions

//--- Data check variables
struct DataStruct
  {
   datetime expectedDT; //Expected datetime
   datetime actualDT; //Actual datetime
  };
DataStruct missData[], addData[];   
int missCount=0, addCount=0;

//--- Results variables
int totalBars, missSeqCount=0, addSeqCount=0, contCount=1;
double ratioMiss, ratioAdd, ratioAvail;
datetime tempExpected=0, tempActual=0, tempNext=0, tempStartDate=0;
struct DataSeqStruct
  {
   int count;
   datetime from;
   datetime to;
  };
DataSeqStruct missSeqData[], addSeqData[];


//--- Export variables
string brokerName, fileName, filePath, fullPath;

//+------------------------------------------------------------------+
//| Main scritping function                                          |
//+------------------------------------------------------------------+
void OnStart()
  {
   //Inform terminal that script has started
   Print("");
   PrintFormat("-------- PxStrat™ %s script started --------",__FILE__);
   startTick = GetTickCount();

//+------------------------------------------------------------------+
//| Check inputs                                                     |
//+------------------------------------------------------------------+
   if(startDate > endDate) //Check that startDate is before endDate
     {
      Print("Error: Start date is after end date.");
      PrintFormat("-------- PxStrat™ %s script ended - Duration: %i ms --------",__FILE__,duration);
      return;
     }
   if(startDate == endDate) //Check that startDate is not equal to endDate
     {
      Print("Error: Start date is equal to end date.");
      PrintFormat("-------- PxStrat™ %s script ended - Duration: %i ms --------",__FILE__,duration);
      return;
     }
   if(startDate > TimeCurrent() || endDate > TimeCurrent())
     {
      Print("Input dates are in the future.");
      PrintFormat("-------- PxStrat™ %s script ended - Duration: %i ms --------",__FILE__,duration);
      return;
     }
   
//+------------------------------------------------------------------+
//| Download price data                                              |
//+------------------------------------------------------------------+
   PrintFormat("Copying price data...");
   availableBars = CopyRates(Symbol(),PERIOD_M1,startDate,endDate,priceData);
   
   //Check results from CopyRates operation
   if(availableBars==-1 || availableBars==0)
     {
      PrintFormat("Price data not copied - try increasing TERMINAL_MAXBARS settings and try again");
      duration = GetTickCount() - startTick;
      PrintFormat("-------- PxStrat™ %s script ended - Duration: %i ms --------",__FILE__,duration);
      return;
     }    
   if(availableBars > 0)
     {
      //Record the available start and end date 
      adjStartDate = priceData[0].time; adjEndDate = priceData[availableBars-1].time+60;
     }
   
//+------------------------------------------------------------------+
//| Record quote session hours                                       |
//+------------------------------------------------------------------+
   for(int weekDay=0; weekDay<7; weekDay++)
     {
      for(int sessionIndex=0; sessionIndex<10; sessionIndex++)
        {
         if(SymbolInfoSessionQuote(Symbol(),(ENUM_DAY_OF_WEEK)weekDay,sessionIndex,openDT,closeDT) == true)
           {
            //Note opening and closing times of session if true
            quoteSession[weekDay][sessionIndex].quoteStatus = true;
            quoteSession[weekDay][sessionIndex].openDT = openDT;
            quoteSession[weekDay][sessionIndex].closeDT = closeDT;
           }
         else
           {
            //Note opening and closing times of session if  false
            quoteSession[weekDay][sessionIndex].quoteStatus = false;
            quoteSession[weekDay][sessionIndex].openDT = 0;
            quoteSession[weekDay][sessionIndex].closeDT = 0;
           }  
        }
     }
   
//+------------------------------------------------------------------+
//| Check data quality                                               |
//+------------------------------------------------------------------+
   ArrayResize(missData,availableBars); ArrayResize(addData,availableBars);
   checkDate=adjStartDate; //Ensure first checking date is equal to first data point copied
   for(int i=0; i<availableBars; i++)
     {      
      //Check if price data point is within quote sessions
      if(CheckQuoteSession(checkDate))
        {
         //If missing data-points exist
         if(checkDate < priceData[i].time)
           {
            missData[missCount].expectedDT = checkDate;
            missData[missCount].actualDT = priceData[i].time;
            checkDate+=60; missCount++; i--; //Adjust checkDate and counters
            continue;
           }
         //If data points exist
         if(checkDate == priceData[i].time)
           {
            checkDate+=60; continue; //Adjust checkDate
           }   
         //If additional data-points exist
         if(checkDate > priceData[i].time)
           {
            addData[addCount].expectedDT = checkDate;
            addData[addCount].actualDT = priceData[i].time;
            addCount++; //Adjust counter
            continue;
           }
        }
      else
        {
         checkDate+=60; i--; //Adjust checkDate and counter
        } 
     }
   ArrayResize(missData,missCount); ArrayResize(addData,addCount);
   
//+------------------------------------------------------------------+
//| Evaluate results                                                 |
//+------------------------------------------------------------------+
   //Evaluate broker name
   brokerName=AccountInfoString(ACCOUNT_COMPANY);
   brokerName=StringSubstr(brokerName,0,StringFind(brokerName,"."));
   
   //Evaluate key statistics
   totalBars = availableBars+missCount-addCount;
   ratioAvail = (double)availableBars/(double)totalBars*100;
   ratioMiss = (double)missCount/(double)totalBars*100; ratioAdd = (double)addCount/(double)totalBars*100;
   
   //Evaluate sequences of missing and additional data
   ArrayResize(missSeqData,missCount); ArrayResize(addSeqData,addCount);
   
   //Missing sequence check
   if(missCount != 0) tempExpected = missData[0].expectedDT; //Establish first expected missing value
   for(int i=1; i<missCount; i++)
     {
      tempNext = missData[i].expectedDT; //Establish next expected value in the sequence
      if(contCount==1) tempStartDate = tempExpected; //Record the first date of the sequence
      //If the next value is in sequence
      if(tempNext == tempExpected+60 && i<missCount-1)
        { 
         tempExpected = tempNext; //Assign the tempNext to tempExpected, so that the loop can be repeated
         contCount++; //Increase the count, which keeps track of how many sequentially missing datapoints exist
        }
      //If the next value is further than 1 minute away, then it means that sequence of missing values has stopped  
      else if(tempNext > tempExpected+60 || i==missCount-1)
        {
         //Record sequence data
         missSeqData[missSeqCount].count = contCount;
         missSeqData[missSeqCount].from = tempStartDate;
         missSeqData[missSeqCount].to = tempExpected+60;
         contCount=1; missSeqCount++; //Adjust counters
         tempExpected = tempNext; //Set the expected value as the next missing value.
        }  
     }
   
   contCount=1;
   //Additional sequence check
   if(addCount != 0) tempActual = addData[0].actualDT; //Establish first expected additional value
   for(int i=1; i<addCount; i++)
     {
      tempNext = addData[i].actualDT; //Establish next expected value in the sequence
      if(contCount == 1) tempStartDate = tempActual; //Record the first date of the sequence
      //If the next value is in sequence
      if(tempNext == tempActual+60 && i<addCount-1)
        { 
         tempActual = tempNext; //Assign the tempNext to tempActual, so that the loop can be repeated
         contCount++; //Increase the count, which keeps track of how many sequentially additional datapoints exist
        }
      //If the next value is further than 1 minute away, then it means that sequence of missing values has stopped  
      else if(tempNext > tempActual+60 || i==addCount-1)
        {
         //Record sequence data
         addSeqData[addSeqCount].count = contCount;
         addSeqData[addSeqCount].from = tempStartDate;
         addSeqData[addSeqCount].to = tempActual+60;
         contCount=1; addSeqCount++; //Adjust counters
         tempActual = tempNext; //Set the expected value as the next missing value.
        }  
     }
   ArrayResize(missSeqData,missSeqCount); ArrayResize(addSeqData,addSeqCount);
   
//+------------------------------------------------------------------+
//| Export results                                                   |
//+------------------------------------------------------------------+
   fileName = StringFormat("PxStrat//Data Quality//%s %s Data Quality.csv",Symbol(),brokerName);
   FileDelete(fileName,0);
   int fileHandle=FileOpen(fileName,FILE_READ|FILE_WRITE|FILE_CSV);
   if(fileHandle!=INVALID_HANDLE)
     {
      FileWrite(fileHandle,"PxStrat™","https://www.pxstrat.co.uk");
      FileWrite(fileHandle,"Title","Data Quality 1.0");
      FileWrite(fileHandle,"Date",TimeLocal());
      FileWrite(fileHandle,"Symbol",Symbol());
      FileWrite(fileHandle,"Broker",brokerName);
      FileWrite(fileHandle,"From",adjStartDate);
      FileWrite(fileHandle,"To",adjEndDate);
      FileWrite(fileHandle,"");
      FileWrite(fileHandle,"Overview","#","%");
      FileWrite(fileHandle,"Total number of bars",totalBars,100);
      FileWrite(fileHandle,"Number of available bars",availableBars,ratioAvail);
      FileWrite(fileHandle,"Number of missing bars",missCount,ratioMiss);
      FileWrite(fileHandle,"");
         
      //Exporting missing seqeunces
      FileWrite(fileHandle,"Top 10 missing data sequences");
      FileWrite(fileHandle,"Bars","From","To");
      int maxCount, maxIndex=0;
      for(int u=0; u<10 && u<missSeqCount; u++)
        {
         maxCount=0;
         for(int i=0; i<missSeqCount; i++)
           {
            if(maxCount<missSeqData[i].count)
              {
               maxCount=missSeqData[i].count; maxIndex=i;
              }
           }
         FileWrite(fileHandle,missSeqData[maxIndex].count,missSeqData[maxIndex].from,missSeqData[maxIndex].to);
         missSeqData[maxIndex].count=0;
        }
      
      FileClose(fileHandle);  
     }
   else
     {
      PrintFormat("Failed to export data, error Code = %d",GetLastError());
     }
   
   //Inform the user of quality check completion and datapath
   filePath = TerminalInfoString(TERMINAL_DATA_PATH);
   fullPath = filePath+"//MQL5//Files//"+fileName;
   Print("Data quality check completed");
   Print("Results exported to ",fullPath);
   
   //Inform terminal that script has finished
   duration = GetTickCount() - startTick;
   PrintFormat("-------- PxStrat™ %s script ended - Duration: %i ms --------",__FILE__,duration);
   Print("");
  }

//+------------------------------------------------------------------+
//| Function to check quote session                                  |
//+------------------------------------------------------------------+
bool CheckQuoteSession(datetime checkDT)
  {
   //Local variables
   datetime adjCheckDT, tempHolderDT;
   MqlDateTime tempHolderST;
   
   //Adjust checkDT by reducing datetime value to allow comparison
   TimeToStruct(checkDT,tempHolderST);
   tempHolderST.hour=0; tempHolderST.min=0; tempHolderST.sec=0;
   tempHolderDT = StructToTime(tempHolderST);
   adjCheckDT = checkDT-tempHolderDT;
   
   //Establish if checkDT falls within a quote session
   for(int sessionIndex=0; sessionIndex<10; sessionIndex++)
     {
      if(quoteSession[tempHolderST.day_of_week][sessionIndex].quoteStatus == true)
        {
         if(adjCheckDT >= quoteSession[tempHolderST.day_of_week][sessionIndex].openDT &&
            adjCheckDT < quoteSession[tempHolderST.day_of_week][sessionIndex].closeDT)
            return(true);
        }
     }  
   return(false);
  }
