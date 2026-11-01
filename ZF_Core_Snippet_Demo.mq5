//+------------------------------------------------------------------+
//| ZFT - Zuhri Formalism Token - Snippet Demo                      |
//| ZF_Core Demo - 300 lines - Portfolio Edition                     |
//| Concept & Formalism by Founder (2023-2026)                        |
//| Implementation assisted by AI - Full 3409 lines private          |
//| Live: https://zftoken-zft1.vercel.app/                           |
//+------------------------------------------------------------------+
#property copyright "© 2026 Zuhri Formalism - Portfolio Demo"
#property link      "https://zftoken-zft1.vercel.app/"
#property version   "V21.30-Snippet-Demo"
#property description "ZF Value Demo - Full EA 3409 lines available upon request"

//--- Inputs
input double InpZFThresholdBuy  = 0.70;
input double InpZFThresholdSell = 0.30;
input int    InpADXPeriod      = 14;
input double InpRetracePct     = 0.50;

//--- Globals
double gZFValue = 0.0;
string gDEC = "WAIT";
double gCONF = 0.0;

//+------------------------------------------------------------------+
//| Calculate ADF - Auction Distribution Factor                      |
//+------------------------------------------------------------------+
double CalculateADF(string symbol, int timeframe)
{
   // ADF measures auction imbalance
   double high = iHigh(symbol, timeframe, 1);
   double low  = iLow(symbol, timeframe, 1);
   double close = iClose(symbol, timeframe, 1);
   double open  = iOpen(symbol, timeframe, 1);
   
   double range = high - low;
   if(range == 0) return 0.5;
   
   double bodyPos = (close - low) / range;
   double wickFactor = MathAbs(close - open) / range;
   
   // ADF 0-1: 0 bearish auction, 1 bullish auction
   double adf = (bodyPos * 0.6 + wickFactor * 0.4);
   return MathMax(0.0, MathMin(1.0, adf));
}

//+------------------------------------------------------------------+
//| Calculate CONF - Confidence                                      |
//+------------------------------------------------------------------+
double CalculateCONF(string symbol, int timeframe)
{
   // CONF from swing structure + ADX
   double adx = iADX(symbol, timeframe, InpADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double plusDI = iADX(symbol, timeframe, InpADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 1);
   double minusDI = iADX(symbol, timeframe, InpADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 1);
   
   double diDiff = MathAbs(plusDI - minusDI);
   double adxNorm = MathMin(adx / 50.0, 1.0);
   double diNorm = MathMin(diDiff / 20.0, 1.0);
   
   double conf = adxNorm * 0.7 + diNorm * 0.3;
   return MathMax(0.0, MathMin(1.0, conf));
}

//+------------------------------------------------------------------+
//| Calculate Speed - Price velocity                                 |
//+------------------------------------------------------------------+
double CalculateSpeed(string symbol, int timeframe)
{
   double close1 = iClose(symbol, timeframe, 1);
   double close2 = iClose(symbol, timeframe, 2);
   double atr = iATR(symbol, timeframe, 14, 1);
   
   if(atr == 0) return 0.5;
   double speed = MathAbs(close1 - close2) / atr;
   double speedNorm = MathMin(speed / 2.0, 1.0);
   return speedNorm;
}

//+------------------------------------------------------------------+
//| Calculate Tick Density                                           |
//+------------------------------------------------------------------+
double CalculateTickDensity()
{
   // Simplified tick density
   // Real implementation uses OnTick counting
   static datetime lastTime = 0;
   static int tickCount = 0;
   
   datetime curTime = TimeCurrent();
   if(curTime - lastTime >= 60)
   {
      lastTime = curTime;
      tickCount = 0;
   }
   tickCount++;
   double density = MathMin(tickCount / 100.0, 1.0);
   return density;
}

//+------------------------------------------------------------------+
//| Calculate ZF Value - Core Formula                                |
//| ZF(t) = 0.35*ADF + 0.30*CONF + 0.20*Speed + 0.15*Tick             |
//+------------------------------------------------------------------+
double CalculateZFValue(string symbol, int timeframe)
{
   double adf = CalculateADF(symbol, timeframe);
   double conf = CalculateCONF(symbol, timeframe);
   double speed = CalculateSpeed(symbol, timeframe);
   double tick = CalculateTickDensity();
   
   double zf = 0.35 * adf + 0.30 * conf + 0.20 * speed + 0.15 * tick;
   zf = MathMax(0.0, MathMin(1.0, zf));
   
   gZFValue = zf;
   gCONF = conf;
   
   return zf;
}

//+------------------------------------------------------------------+
//| Determine DEC - Decision Logic                                   |
//+------------------------------------------------------------------+
string DetermineDEC(double zf, double conf, double adx)
{
   string dec = "WAIT";
   
   if(zf > 0.70 && conf > 0.65 && adx > 25)
      dec = "A"; // Strong momentum
   else if(zf > 0.55 && conf > 0.50)
      dec = "B"; // Retrace + exhaustion
   else if(zf < 0.30 && conf > 0.60)
      dec = "A"; // Strong bearish
   else if(zf < 0.45 && conf > 0.45)
      dec = "B";
   else
      dec = "C"; // Wait / Counter-trend safety
   
   gDEC = dec;
   return dec;
}

//+------------------------------------------------------------------+
//| Retrace Detection - Asia Session Example                         |
//| Example: AUDUSD 0.70167 BREAK LOW WAIT 0.70250                   |
//+------------------------------------------------------------------+
bool IsRetraceValid(string symbol, double currentPrice, double asiaLow, double asiaHigh)
{
   double asiaRange = asiaHigh - asiaLow;
   double midAsia = asiaLow + InpRetracePct * asiaRange;
   double buffer = 5 * _Point * 10; // 5 pips buffer
   
   // For SELL: price must retrace up to midAsia after breaking low
   if(currentPrice <= asiaLow)
   {
      // Break detected - wait retrace
      if(currentPrice >= (midAsia - buffer) && currentPrice <= (midAsia + buffer))
         return true; // Valid retrace - can SELL
      else
         return false; // Wait retrace
   }
   
   // For BUY: similar logic inverted
   if(currentPrice >= asiaHigh)
   {
      if(currentPrice >= (midAsia - buffer) && currentPrice <= (midAsia + buffer))
         return true;
      else
         return false;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Example Usage in OnTick                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   string symbol = _Symbol;
   int tf = PERIOD_M5;
   
   double zf = CalculateZFValue(symbol, tf);
   double adx = iADX(symbol, tf, InpADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   string dec = DetermineDEC(zf, gCONF, adx);
   
   // Example: XAUUSD 3967.95 BREAK LOW WAIT RETRACE 4011.3
   // Panel output:
   // ZF 0.221 STABLE - CHOPPY - DEC A SELL blocked by WAIT RETRACE
   
   // Full logic with 3409 lines includes:
   // - DXY correlation filter
   // - Swing high/low detection
   // - Exhaustion override
   // - Session filters
   // - Risk management
   // Available upon request for hiring
}

//+------------------------------------------------------------------+
//| Proof-of-Profit Anti-Luck Filter (Concept)                       |
//| 6 factors - Portfolio Demo                                       |
//+------------------------------------------------------------------+
/*
bool PassPoPFilter(double pf, double sharpe, int maxConsecLoss, int totalTrades, double lotStdMean, double zfAvg)
{
   if(pf < 1.5) return false;
   if(sharpe < 1.2) return false;
   if(maxConsecLoss >= 5) return false;
   if(totalTrades < 50) return false;
   if(lotStdMean > 0.30) return false; // Anti-martingale
   if(zfAvg < 0.45) return false;
   return true;
}
*/
//+------------------------------------------------------------------+
