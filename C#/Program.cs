
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Net;
using System.IO;
using Newtonsoft.Json;
using HtmlAgilityPack;

using System.Text.RegularExpressions;
using System.Collections;
using System.Collections.Specialized;

using System.Data.SqlClient;

namespace UNEScrape
{
    class Program
    {

        public static string dataDir = @"..\..\data\";

        static void Main(string[] args)
        {        

            // UNESCAP main page
            string mainPageHtml = "";
            string mainPage = "http://www.unescap.org/stat/data/statdb/DataExplorer.aspx";
            string mainPageFile = GetPageFromUrl(mainPage) + ".htm";

            // get html from main page  (save once)
            mainPageHtml = GetHtml(mainPage, true);            
            if (SaveToDisk(mainPageHtml, mainPageFile)) { Console.WriteLine("Page saved to {0}", mainPageFile); }

            // read (for testing)
            if (ReadFromDisk(ref mainPageHtml, mainPageFile)) { Console.WriteLine("Page read from{0}", mainPageFile); }

            // grab input list (single node) of countries
            HtmlDocument doc = new HtmlDocument();
            doc.Load(Program.dataDir + mainPageFile);

            var inode = doc.DocumentNode.SelectSingleNode("//input[@name='indicatorsXml']");
            string indicatorList = WebUtility.HtmlDecode(inode.Attributes["value"].Value);
            indicatorList = indicatorList.Replace("&amp;", "&"); // this was "double" escaped in original html (i.e. &ampamp;)
            indicatorList = indicatorList.Replace("&#39;", "'"); // HtmlDecode failed to find this! Why?

            // test
            // HtmlDocument docx = new HtmlDocument();
            //docx.LoadHtml(indicatorList);
            //Test.EnumIndicators(docx.DocumentNode);
            //return;
            
            // Indicators
            ArrayList indicators = new ArrayList();
            indicators = ParseIndicatorsFromHtml(indicatorList);

            // areas
            var anode = doc.DocumentNode.SelectSingleNode("//input[@name='serieslistXml']");
            string areaList = WebUtility.HtmlDecode(anode.Attributes["value"].Value);

            // get just area ID's put in array
            ArrayList areas = new ArrayList();
            areas = ParseAreasFromHtml(areaList);
            string[] areaIDs = new string[] { };
            Array.Resize(ref areaIDs, areas.Count);
            int i = 0;
            foreach (Area area in areas)
            {
                areaIDs[i] = area.ID;
                i++;
            }

            // loop through indicators
            int k = 0;
            //int stop = 10;
            foreach (Indicator ind in indicators)
            {
                k++;
                CallGetDataWebService(ind.ID, ind.UID, areaIDs, ind.Text);

                if (k % 10 == 0) { Console.WriteLine("\n{0} Indicators Processed ...\n", k.ToString());  }

                //if (k == stop) { break; }
            }
            //Console.WriteLine("\nIndicator Count = {0}\n", indicators.Count.ToString());

            // write saved .JSON files to SQL Server
            WriteJsonStatsToSQLServer();

        }

        public static void AreasToSqlScript()
        {

            string mainPage = "http://www.unescap.org/stat/data/statdb/DataExplorer.aspx";
            string mainPageFile = GetPageFromUrl(mainPage) + ".htm";

            // grab input list (single node) of countries
            HtmlDocument doc = new HtmlDocument();
            doc.Load(Program.dataDir + mainPageFile);

            var anode = doc.DocumentNode.SelectSingleNode("//input[@name='serieslistXml']");
            string areaList = WebUtility.HtmlDecode(anode.Attributes["value"].Value);

            // get just area ID's put in array
            ArrayList areas = new ArrayList();
            areas = ParseAreasFromHtml(areaList);

            foreach (Area area in areas)
            {
                Console.WriteLine(String.Format("INSERT INTO un.Area VALUES({0}, '{1}')", area.ID, area.Text));
            }

        }

        public static void CallGetDataWebService(string id, string uid, string[] areas, string indText)
        {

            string jsonFile = id + "-" + uid + ".json";

            string qq = ((char)34).ToString(); // double quote

            string url = "http://www.unescap.org/stat/data/statdb/StatWorksDataService.svc/GetData";

            string indList = WebUtility.UrlEncode("[{\"ID\":" + qq + id.ToString() + qq + ",\"ID2\":" + qq + uid.ToString() + qq + "}]");
            string areaList = WebUtility.UrlEncode("[" + qq + String.Join(qq + "," + qq, areas) + qq + "]");
            string query = String.Format("indicatorIDsUnitIDs={0}&areaIDs={1}&includeMetaData=false", indList, areaList);
            string uri = url + "?" + query;

            //Console.WriteLine(uri);

            string json = GetJson(uri);
            bool success = SaveToDisk(json, jsonFile);
            if (success) { Console.WriteLine("{1} -> {0}", jsonFile, indText); }

        }

        public static ArrayList ParseAreasFromHtml(string list)
        {

            HtmlDocument doc2 = new HtmlDocument();
            doc2.LoadHtml(list);

            ArrayList leafNodes = new ArrayList();
            ArrayList areas = new ArrayList();

            GetLeafNodes(doc2.DocumentNode, ref leafNodes);

            int nodeCount = 0;
            foreach (HtmlNode node in leafNodes)
            {
                nodeCount++;

                string id = node.Attributes["id"].Value;
                string text = node.Attributes["text"].Value;

                Area area = new Area();
                area.ID = id;
                area.Text = text;
                areas.Add(area);

            }

            return areas;

        }

        public static ArrayList ParseIndicatorsFromHtml(string list)
        {

            HtmlDocument doc2 = new HtmlDocument();
            doc2.LoadHtml(list);

            ArrayList leafNodes = new ArrayList();
            ArrayList indicators = new ArrayList();

            GetLeafNodes(doc2.DocumentNode, ref leafNodes);
            StringBuilder sb = new StringBuilder("");

            int nodeCount = 0;
            foreach (HtmlNode node in leafNodes)
            {
                nodeCount++;

                string id = node.Attributes["id"].Value;
                string uid = node.Attributes["uid"].Value;
                string text = node.Attributes["text"].Value;

                string idText = "";
                string uidText = "";

                Match match = Regex.Match(text, @"^(.+)\[(.+?)\]$", RegexOptions.RightToLeft);
                if (match.Success)
                {
                    idText = match.Groups[1].Value;
                    uidText = match.Groups[2].Value;
                }

                if (uid == "")
                {
                    Console.WriteLine("*** BAD NODE *** {0} -> {1}", id, text);
                }
                else
                {
                    Indicator ind = new Indicator();
                    ind.ID = id;
                    ind.UID = uid;
                    ind.Text = text;
                    ind.IDText = idText;
                    ind.UIDText = uidText;
                    indicators.Add(ind);
                    //sb.AppendLine(String.Join("|", new string[] { nodeCount.ToString(), id, uid, text, idText, uidText }));
                    //sb.AppendFormat("INSERT INTO dbo.Indicator VALUES({0}, {1}, {2}, '{3}', '{4}', '{5}')\n", nodeCount.ToString(), id, uid, text, idText, uidText);
                }


                //Console.WriteLine("{0}/{1} -> {2} -> {3} | {4}", id, uid, text, idText, uidText);
            }

            return indicators;

            //bool saved = SaveToDisk(sb.ToString(), "Indicators.sql");

        }


        public static void GetLeafNodes(HtmlNode node, ref ArrayList leafNodes)
        {

            // create nodes collection (to ensure a single node passed will fire the FOREACH loop below)
            HtmlNodeCollection nodes;
            if (node.HasChildNodes)
            {
                nodes = node.ChildNodes;
            }
            else
            {
                nodes = new HtmlNodeCollection(node);
            }

            foreach (HtmlNode inode in nodes)
            {
                if (inode.HasChildNodes)
                {
                    GetLeafNodes(inode, ref leafNodes);
                }
                else
                {
                    leafNodes.Add(inode);
                }
            }

        }

        // overload - if no dir passed use ..\..\data
        public static bool SaveToDisk(string text, string fileName)
        {
            return SaveToDisk(text, fileName, Program.dataDir);
        }
        
        public static bool SaveToDisk(string text, string fileName, string dirName)
        {
            if (!dirName.EndsWith(@"\")) { dirName += @"\"; }
            fileName = dirName + fileName;
            try
            {
                File.WriteAllText(fileName, text, Encoding.UTF8);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                return false;
            }
        }


        // overload - if no dir passed use ..\..\data
        public static bool ReadFromDisk(ref string text, string fileName)
        {
            return ReadFromDisk(ref text, fileName, Program.dataDir);
        }

        public static bool ReadFromDisk(ref string text, string fileName, string dirName)
        {
            if(!dirName.EndsWith(@"\")) { dirName += @"\"; }
            fileName = dirName + fileName;
            try
            {
                text = File.ReadAllText(fileName, Encoding.UTF8);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                return false;
            }
        }


        public static void WriteJsonStatsToSQLServer()
        {

            // log file
            LogWriter log = new LogWriter("Opened");
                        
            SqlConnection connection;
            string connectionString = @"Persist Security Info=False;User ID=dev;Password=******;Initial Catalog=DEV;Server=TOBOR\SQL2014EXP";

            try
            {
                connection = new SqlConnection(connectionString);
                connection.Open();
            }
            catch (SqlException sex)
            {
                Console.WriteLine("\nSQL ERROR : {0}", sex.Message);
                return;
            }

            DirectoryInfo di = new DirectoryInfo(@"..\\..\\json\\");
            FileInfo[] Files = di.GetFiles("*.json");

            int i = 0;
            foreach (FileInfo fileName in Files)
            {

                //Console.WriteLine(fileName.Name);
                try
                {
                    ParseStatsFromJson(fileName.Name, connection);
                    log.LogWrite(fileName.Name + " Processed Successfully");
                }
                catch (Exception ex)
                {
                    string errMsg = fileName.Name + " ERROR-> " + ex.Message;
                    log.LogWrite(errMsg);
                    Console.WriteLine(errMsg + "\n");
                }

                i++;

                // test
                //if (i == 30) { break; }
                
                if (i % 50 == 0) { Console.WriteLine("\n{0} FILES PROCESSED\n", i.ToString());  }

            }

            connection.Close();

            log.LogWrite("Closed\n");

        }

        public static void ParseStatsFromJson(string fileName, SqlConnection connection)
        {

            string json = "";
            bool success = ReadFromDisk(ref json, fileName, "..\\..\\json"); // dec data           

            int kpiID;
            int measID;
            Match match = Regex.Match(fileName, @"(\d+)-(\d+)\.json");
            kpiID = Convert.ToInt32(match.Groups[1].Value);
            measID = Convert.ToInt32(match.Groups[2].Value);


            int recCount = 0;

            JStats stats = JsonConvert.DeserializeObject<JStats>(json);
            JStats.D2 d = stats.D;

            // data!
            JStats.Datum[] data = stats.D.Data;
            for (int i = 0; i <= data.GetUpperBound(0); i++)
            {
                JStats.Datum datum = data[i];
                //Console.WriteLine("AreaID -> " + datum.AreaID);
                JStats.DP[] dps = datum.DPs;
                for (int j = 0; j <= dps.GetUpperBound(0); j++)
                {

                    JStats.DP dp = dps[j];
                    //Console.WriteLine("  " + dp.TimeID + " -> " + dp.Value);

                    SqlCommand cmd = new SqlCommand("INSERT INTO un.Stats (AreaID, TimeID, KpiID, MeasureID, Value) VALUES (@AreaID, @TimeID, @KpiID, @MeasureID, @Value)");
                    cmd.CommandType = System.Data.CommandType.Text;
                    cmd.Connection = connection;
                    cmd.Parameters.AddWithValue("@AreaID", datum.AreaID);
                    cmd.Parameters.AddWithValue("@TimeID", dp.TimeID);
                    cmd.Parameters.AddWithValue("@KpiID", kpiID);
                    cmd.Parameters.AddWithValue("@MeasureID", measID);
                    cmd.Parameters.AddWithValue("@Value", dp.Value);
                    cmd.ExecuteNonQuery();

                    recCount++;

                }

                //Console.WriteLine("\n{0} Values Found For AreaID = {1}\n", dps.GetUpperBound(0) + 1, datum.AreaID);
            }


            Console.WriteLine("{0} records written to un.Stats", recCount.ToString());
            recCount = 0;

            // times
            for (int k = 0; k <= d.Times.GetUpperBound(0); k++)
            {

                JStats.Time time = stats.D.Times[k];
                //Console.WriteLine(time.ID + " -> " + time.Name);

                SqlCommand cmd = new SqlCommand("INSERT INTO un.Time (KpiID, MeasureID, TimeID, Label) VALUES (@KpiID, @MeasureID, @TimeID, @Label)");
                cmd.CommandType = System.Data.CommandType.Text;
                cmd.Connection = connection;
                cmd.Parameters.AddWithValue("@KpiID", kpiID);
                cmd.Parameters.AddWithValue("@MeasureID", measID);
                cmd.Parameters.AddWithValue("@TimeID", time.ID);
                cmd.Parameters.AddWithValue("@Label", time.Name);
                cmd.ExecuteNonQuery();

                recCount++;

            }

            Console.WriteLine("{0} records written to un.Stats", recCount.ToString());

            Console.WriteLine("File {0} processed\n", fileName);

        }

        public static void ParseAreasFromJson()
        {

            string json = "";

            json = GetJson("http://www.unescap.org/stat/data/statdb/StatWorksDataService.svc/GetAreas");
            if (json == "") { return; }
            
            //bool success = SaveToDisk(json, "GetAreas.json"); // save to disk once, can test parsing later (w/o having to call web service again and again)

            // test (from disk)            
            //bool success = ReadFromDisk(ref json, "GetAreas.json");

            JAreas areas = JsonConvert.DeserializeObject<JAreas>(json);

            int escapCnt = 0;

            for (int i = 0; i <= areas.D.GetUpperBound(0); i++)
            {

                JAreas.D2 d2 = areas.D[i];

                Console.WriteLine(d2.Name + " -> " + d2.ID);

                if (d2.Chd == null)
                {
                    //Console.WriteLine("  ** No Children **");
                    continue;
                }

                for (int j = 0; j <= d2.Chd.GetUpperBound(0); j++)
                {

                    JAreas.Chd2 chd2 = d2.Chd[j];
                    Console.WriteLine("  >> " + chd2.Name + " -> " + chd2.ID);

                    if (d2.Chd[j].Chd == null)
                    {
                        //Console.WriteLine("  ** No Sub-Children **");
                        continue;
                    }

                    for (int k = 0; k <= d2.Chd[j].Chd.GetUpperBound(0); k++)
                    {
                        JAreas.Chd3 chd3 = d2.Chd[j].Chd[k];
                        Console.WriteLine("    >> " + chd3.Name + " -> " + chd3.ID);
                        if (d2.Name == "ESCAP Countries") { escapCnt++; }
                    }


                }

            }

            Console.WriteLine("\nESCAP Country COUNT = {0}\n", escapCnt.ToString());

        }

        public static string GetHtml(string url, bool unzip)
        {

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
            if (unzip)
            {
                request.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
            }

            try
            {
                WebResponse response = request.GetResponse();
                using (Stream responseStream = response.GetResponseStream())
                {
                    StreamReader reader = new StreamReader(responseStream, Encoding.UTF8);
                    return reader.ReadToEnd();
                }
            }
            catch (WebException ex)
            {
                WebResponse errorResponse = ex.Response;
                using (Stream responseStream = errorResponse.GetResponseStream())
                {
                    StreamReader reader = new StreamReader(responseStream, Encoding.UTF8);
                    String errorText = reader.ReadToEnd();
                }
                throw;
            }


        }

        public static string GetJson(string url)
        {

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);

            // TODO : must check if response is Null first (error might be because we can't make a connection!)
            try
            {
                WebResponse response = request.GetResponse();
                using (Stream responseStream = response.GetResponseStream())
                {
                    StreamReader reader = new StreamReader(responseStream, Encoding.UTF8);
                    return reader.ReadToEnd();
                }
            }
            catch (WebException ex)
            {
                WebResponse errorResponse = ex.Response;
                using (Stream responseStream = errorResponse.GetResponseStream())
                {
                    StreamReader reader = new StreamReader(responseStream, Encoding.UTF8);
                    String errorText = reader.ReadToEnd();
                    Console.WriteLine("Error retrieving JSON : {0}", errorText);
                }
                return "";
                //throw;
            }

        }
        
        public static void RegExTest()
        {

            string text;
            text = "Fixed-telephone subscriptions [Per 100 population]";
            //text = "Income / consumption of poorest quintile(lowest 20 %)[WB][% of income / consumption]";

            //Match match = Regex.Match(text, @"^(.+?) \[(.+)\]$");
            Match match = Regex.Match(text, @"^(.+)\[(.+?)\]$", RegexOptions.RightToLeft);            
                        
            string idText = match.Groups[1].Value.ToString().TrimEnd();
            string uidText = match.Groups[2].Value.ToString(); ;
            Console.WriteLine("{0} -> '{1}' | '{2}'", text, idText, uidText);

        }

        public static string GetPageFromUrl(string url)
        {
            string[] folders = url.Split(new char[] { '/' });
            if (folders != null){
                return folders[folders.GetUpperBound(0)];
            }
            else{
                return "";
            }
        }

    }

}
