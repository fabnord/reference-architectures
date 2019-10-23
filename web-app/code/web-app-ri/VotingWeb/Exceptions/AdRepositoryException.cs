using System;

namespace VotingWeb.Exceptions
{
    public class AdRepositoryException : Exception
    {
        public AdRepositoryException(string message)
        : base(message)
        {
        }

        public AdRepositoryException(string message, Exception inner)
            : base(message, inner)
        {
        }
    }
}
