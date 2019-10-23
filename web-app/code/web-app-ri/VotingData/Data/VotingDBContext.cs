using Microsoft.EntityFrameworkCore;

namespace VotingData.Models
{
    public class VotingDBContext : DbContext
    {
      
        public VotingDBContext()
        {
        }

        public VotingDBContext(DbContextOptions<VotingDBContext> options)
            : base(options)
        {
        }

        public DbSet<Counts> Counts { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Counts>(entity =>
            {
                entity.Property(e => e.Candidate).IsRequired();
            });
        }
    }
}
