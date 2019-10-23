using System;

namespace VotingWeb.Exceptions
{
    public class VoteDataException : Exception
    {
        public VoteDataException(string message)
            : base(message)
        {
        }

        public VoteDataException(string message, Exception inner)
            : base(message, inner)
        {
        }

    }
}
