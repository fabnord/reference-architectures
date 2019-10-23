using System;
using System.Data.SqlClient;
using System.Security;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.ServiceBus.Messaging;
using Newtonsoft.Json.Linq;

namespace FunctionApp
{
    public static class VoteCounter
    {
        [FunctionName("VoteCounter")]
        public static async Task Run([ServiceBusTrigger("votingqueue", AccessRights.Manage,
            Connection = "SERVICEBUS_CONNECTION_STRING")]string myQueueItem, TraceWriter log)
        {

            JObject jObject = JObject.Parse(myQueueItem);
            var Id=(string)jObject["Id"];

            string connectionString;

            try
            {
                connectionString = Environment.GetEnvironmentVariable("sqldb_connection");              
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    string text;
                    conn.Open();

                    text = $"UPDATE dbo.Counts  SET Count = Count + 1 WHERE ID = '{Id}';";

                    using (SqlCommand cmd = new SqlCommand(text, conn))
                    {
                        // Execute the command and log the # rows affected.
                        var rows = await cmd.ExecuteNonQueryAsync();
                        if (rows == 0)
                        {
                            log.Error(String.Format("id entry not found on the database {0}",Id));
                        }
                    }
                }

            }
            catch (Exception ex) when (ex is ArgumentNullException ||
                                    ex is SecurityException ||
                                    ex is SqlException)
            {
                log.Error("Sql Exception",ex);
            }
        
        }
    }
}
