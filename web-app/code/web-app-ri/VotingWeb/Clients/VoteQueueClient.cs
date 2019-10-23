using System;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.ServiceBus;
using VotingWeb.Exceptions;
using VotingWeb.Interfaces;

namespace VotingWeb.Clients
{
    public  class VoteQueueClient: IVoteQueueClient
    {
        private static IQueueClient queueClient;
        private string sbConnectionString;
        private string queueName;

        public VoteQueueClient(string connectionString,string queueName)
        {
            try
            {
                this.sbConnectionString = connectionString;
                this.queueName = queueName;
                queueClient = new QueueClient(sbConnectionString, queueName);
            }
            catch (Exception ex) when (ex is ArgumentException ||
                              ex is ServiceBusException ||
                              ex is UnauthorizedAccessException ||
                              ex is ArgumentNullException)
            {
                throw new VoteQueueException("Initialization Error for service bus", ex);

            }

        }

   

        public async Task SendVoteAsync(string messageBody)
        {

            try
            {
                var message = new Message(Encoding.UTF8.GetBytes(messageBody))
                {
                    ContentType = "application/json",
                };

                await queueClient.SendAsync(message);
            }
            catch (Exception ex) when (ex is ArgumentException ||
                                 ex is ServiceBusException ||
                                 ex is UnauthorizedAccessException ||
                                 ex is ServerBusyException ||
                                 ex is ServiceBusTimeoutException)
            {
                throw new VoteQueueException("Service Bus Exception occurred with sending message to queue",ex);
                            
            }

        }

       
    }
   
}