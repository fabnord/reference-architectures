// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
using System;
using System.Net.Mime;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using VotingWeb.Clients;
using VotingWeb.Interfaces;

namespace VotingWeb
{
    public class Startup
    {
        private readonly ILogger<Startup> logger;

        public Startup(IConfiguration configuration, ILogger<Startup> logger)
        {
            Configuration = configuration;
            this.logger = logger;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            // // Add framework services.
            services.Configure<CookiePolicyOptions>(options =>
            {
                // This lambda determines whether user consent for non-essential cookies is needed for a given request.
                options.CheckConsentNeeded = context => true;
                options.MinimumSameSitePolicy = SameSiteMode.None;
            });


            services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_2);

          
            services.AddSingleton<IVoteQueueClient>(s =>
            new VoteQueueClient(Configuration.GetValue<string>("ConnectionStrings:sbConnectionString")
            ,Configuration.GetValue<string>("ConnectionStrings:queueName")));

            services.AddSingleton<IAdRepository>(s => 
            new AdRepository(Configuration.GetValue<string>("ConnectionStrings:RedisConnectionString"),
                             Configuration.GetValue<string>("ConnectionStrings:CosmosUri"),
                             Configuration.GetValue<string>("ConnectionStrings:CosmosKey")));
    
            services.AddHttpClient<IVoteDataClient, VoteDataClient>(c => {
                c.BaseAddress = new Uri(Configuration.GetValue<string>("ConnectionStrings:VotingDataAPIBaseUri"));

                c.DefaultRequestHeaders.Add(
                    Microsoft.Net.Http.Headers.HeaderNames.Accept,
                    MediaTypeNames.Application.Json);
            });

            logger.LogInformation("Configured Services for Mvc voting web ");
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory loggerFactory)
        {
            app.UseForwardedHeaders(new ForwardedHeadersOptions
            {
                ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
            });

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseBrowserLink();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseCookiePolicy();

            app.UseMvc(
                routes =>
                {
                    routes.MapRoute(
                        name: "default",
                        template: "{controller=Home}/{action=Index}/{id?}");
                });

        }
    }
}