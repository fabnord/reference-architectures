using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace VotingWeb.Exceptions
{
    public class VoteQueueException : Exception
    {
        public VoteQueueException(string message)
            : base(message)
        {
        }

        public VoteQueueException(string message, Exception inner)
            : base(message, inner)
        {
        }
    }
}
