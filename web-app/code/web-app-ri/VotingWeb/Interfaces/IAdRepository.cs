using System.Collections.Generic;
using System.Threading.Tasks;
using VotingWeb.Models;

namespace VotingWeb.Interfaces
{
    public interface IAdRepository
    {
        Task<IList<Ad>>  GetAdsAsync();
    }
}


