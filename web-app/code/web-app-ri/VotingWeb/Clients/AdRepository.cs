using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Newtonsoft.Json;
using StackExchange.Redis;
using VotingWeb.Exceptions;
using VotingWeb.Interfaces;
using VotingWeb.Models;

namespace VotingWeb.Clients
{
    public class AdRepository :IAdRepository
    {

        private static CosmosClient client;
        private static CosmosDatabase database;
        private static CosmosContainer container;
        private static IDatabase cache;
        const string databaseId = "cacheDB";
        const string containerId = "cacheContainer";

        public AdRepository(string cacheConnectionString, 
                                string cosmosEndpointUri, 
                                string cosmosKey)
        {
            try
            {
                Lazy<ConnectionMultiplexer> lazyConnection = GetLazyConnection(cacheConnectionString);
                cache = lazyConnection.Value.GetDatabase();
                client = new CosmosClient(cosmosEndpointUri, cosmosKey);             
                container = client.Databases[databaseId].Containers[containerId];
            }
            catch(Exception ex) when (ex is RedisConnectionException ||
                                      ex is RedisException)
            {
                throw new AdRepositoryException("Redis connection initialization error", ex);
            }
            catch (Exception ex) when (ex is CosmosException)
            {
                throw new AdRepositoryException("Cosmos initialization error", ex);
            }

        }

        private static Lazy<ConnectionMultiplexer> GetLazyConnection(string connectionString)
        {
            return new Lazy<ConnectionMultiplexer>(() =>
            {
                return ConnectionMultiplexer.Connect(connectionString);
            });
        }

        public async Task<IList<Ad>> GetAdsAsync()
        {
            
            List<Ad> ads = new List<Ad>();

            try
            {
                var response = await cache.StringGetAsync("1").ConfigureAwait(false);
             
                if (String.IsNullOrEmpty(response))
                {
                    var sqlQueryText = "SELECT * FROM c WHERE c.MessageType = 'AD'";
                    var partitionKeyValue = "AD";  // Message type 

                    CosmosSqlQueryDefinition queryDefinition = new CosmosSqlQueryDefinition(sqlQueryText);
                    CosmosResultSetIterator<Ad> queryResultSetIterator = container.Items.CreateItemQuery<Ad>(queryDefinition, partitionKeyValue);
                    while (queryResultSetIterator.HasMoreResults)
                    {
                        CosmosQueryResponse<Ad> currentResultSet = await queryResultSetIterator.FetchNextSetAsync();
                        ads.AddRange(currentResultSet);
                    }

                     await cache.StringSetAsync("1", JsonConvert.SerializeObject(ads.First()), TimeSpan.FromMinutes(10));
                }
                else
                {
                    ads.Add(JsonConvert.DeserializeObject<Ad>(response));
                }


            }
            catch (Exception ex) when (ex is RedisConnectionException ||
                                       ex is RedisException || 
                                       ex is RedisCommandException ||
                                       ex is RedisServerException ||
                                       ex is RedisTimeoutException ||
                                       ex is CosmosException || 
                                       ex is TimeoutException)
            {
                throw new AdRepositoryException("Repository Connection Exception", ex);
            }

            return ads;

        }


    }
}
