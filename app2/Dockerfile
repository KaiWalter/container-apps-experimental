FROM mcr.microsoft.com/dotnet/sdk:6.0 AS installer-env

# Build requires 3.1 SDK
COPY --from=mcr.microsoft.com/dotnet/core/sdk:3.1 /usr/share/dotnet /usr/share/dotnet

COPY . /src/dotnet-app
RUN cd /src/dotnet-app && \
    mkdir -p /home/output && \
    dotnet publish *.csproj --output /home/output

FROM mcr.microsoft.com/dotnet/aspnet:3.1
WORKDIR /app
COPY --from=installer-env ["/home/output", "/app"]
ENTRYPOINT ["dotnet", "app2.dll"]