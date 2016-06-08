
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

namespace UNEScrape
{
    class Test
    {

        static void AdHocTest()
        {
            
            // look at escaped string of Indicators from url
            string sig = "indicatorIDsUnitIDs=%5B%7B%22ID%22%3A%222406%22%2C%22ID2%22%3A%22880%22%7D%5D&areaIDs=%5B%2254%22%5D&includeMetaData=false";
            Console.WriteLine(WebUtility.UrlDecode(sig));
            return;

            // Test web service
            Program.CallGetDataWebService("2406", "880", new string[] {"115", "103", "119"}, "");
            return;


        }

        public static void TestUrl()
        {

            string url = "www.unescap.org/stat/data/statdb/StatWorksDataService.svc/GetData";
            string query = "indicatorIDsUnitIDs=%5B%7B%22ID%22%3A%222406%22%2C%22ID2%22%3A%22880%22%7D%5D&areaIDs=%5B%22115%22%2C%22103%22%2C%22119%22%5D&includeMetaData=false";

            Console.WriteLine(WebUtility.UrlDecode(query));
            return;

            //Uri uri = new Uri(url + "?" + parms);
            //Console.WriteLine(uri.Query);

            string[] parms = query.Split(new char[] { '&' });
            NameValueCollection keyVal = new NameValueCollection();
            foreach (string parm in parms)
            {
                string[] pair = parm.Split(new char[] { '=' });
                keyVal[pair[0]] = pair[1];
            }

            foreach (string key in keyVal.Keys)
            {
                Console.WriteLine("{0} -> {1}", key, WebUtility.UrlDecode(keyVal[key]));
            }
        }


        static void DoIt(string list)
        {
            HtmlDocument doc2 = new HtmlDocument();
            doc2.LoadHtml(list);
            var nodes2 = doc2.DocumentNode.SelectNodes("//tvnx");

            if (nodes2 != null)
            {
                Console.WriteLine("Nodes Found!");
                foreach (var node2 in nodes2)
                {
                    var id = node2.Attributes["id"].Value;
                    var text = node2.Attributes["text"].Value;
                    var uid = node2.Attributes["uid"].Value;
                    Console.WriteLine(id + " -> " + text + " / " + uid);
                }
            }
            else
            {
                Console.WriteLine("No Nodes Found!");
            }

        }

        public static void EnumIndicators(HtmlNode node)
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

                string parentId = inode.ParentNode.GetAttributeValue("id", "").ToString();                
                string id = inode.GetAttributeValue("id", "").ToString();
                string uid = inode.GetAttributeValue("uid", "").ToString();
                string text = inode.GetAttributeValue("text", "").ToString().TrimEnd();
                string idText = "";
                string uidText = "";

                Match match = Regex.Match(text, @"^(.+)\[(.+?)\]$", RegexOptions.RightToLeft);
                if (match.Success)
                {
                    idText = match.Groups[1].Value.TrimEnd();
                    uidText = match.Groups[2].Value.TrimEnd();
                }

                string record = String.Join("|", new string[] { parentId, id, uid, text, idText, uidText });
                Console.WriteLine(record);

                if (inode.HasChildNodes)
                {
                    EnumIndicators(inode);
                }

            }


        }

        public static void EnumerateNode(HtmlNode node)
        {
            EnumerateNode(node, 1, "");
        }

        public static void EnumerateNode(HtmlNode node, int nodeDepth, string path)
        {

            if (nodeDepth <= 2) { path = ""; }

            string pad = new string('-', 2 * (nodeDepth - 1));

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
                //foreach (var val in inode.Attributes) { Console.WriteLine(val.Name + "  --> " + val.Value); }
                Console.WriteLine(pad + inode.GetAttributeValue("text", "<NOT FOUND>").ToString() + " -> Depth = " + nodeDepth);
                path = path + inode.GetAttributeValue("text", "<NOT FOUND>").ToString() + "/";
                if (inode.HasChildNodes)
                {
                    EnumerateNode(inode, nodeDepth + 1, path);
                }
            }

            Console.WriteLine("\nPATH >> {0}\n", path);


        }



    }
}
