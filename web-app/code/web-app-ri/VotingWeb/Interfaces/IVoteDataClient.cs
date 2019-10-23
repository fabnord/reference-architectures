using System.Collections.Generic;
using System.Net.Http;
using System.Threading.Tasks;
using VotingWeb.Models;

namespace VotingWeb.Interfaces
{
    public interface IVoteDataClient
    {
        Task<IList<Counts>> GetCountsAsync();

        Task<HttpResponseMessage> AddVoteAsync(string candidate);

        Task DeleteCandidateAsync(string candidate);


    }
}
