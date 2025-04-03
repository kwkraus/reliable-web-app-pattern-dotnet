# GitHub Copilot Custom Instructions for .NET 9 Development

## General Guidelines
1. **Target Framework**: Always use `.NET 9` features and APIs when applicable.
2. **Project Types**: Focus on Web API projects, ASP.NET Core applications, Azure Functions, and Azure Cloud development.
3. **Code Style**:
   - Follow **PascalCase** for class names, method names, and public properties.
   - Use **camelCase** for local variables, private fields (prefix with `_`), and method parameters.
   - Use meaningful and descriptive names for all variables, methods, and classes.
   - Avoid abbreviations unless they are widely accepted (e.g., `Http`, `Url`).
4. **Comments** Always add comments to your code, explaining what each part does.

## Logging
1. Use the built-in **Microsoft.Extensions.Logging** framework for logging.
2. Always log at appropriate levels (`Trace`, `Debug`, `Information`, `Warning`, `Error`, `Critical`).
3. Include contextual information in log messages to aid debugging.

Example:
```csharp
_logger.LogInformation("Processing request for {UserId}", userId);
```

## Dependency Injection
1. Use **constructor injection** for injecting dependencies.
2. Register services in the `IServiceCollection` using appropriate lifetimes (`Singleton`, `Scoped`, `Transient`).
3. Avoid using the `ServiceLocator` pattern.

Example:
```csharp
public class MyService : IMyService
{
    private readonly IMyDependency _dependency;

    public MyService(IMyDependency dependency)
    {
        _dependency = dependency;
    }
}
```

## Asynchronous Programming
1. Use `async`/`await` for all asynchronous operations.
2. Avoid blocking calls (e.g., `Task.Wait()` or `Task.Result()`).
3. Use `ConfigureAwait(false)` in library code to avoid deadlocks.

Example:
```csharp
public async Task<IActionResult> GetDataAsync()
{
    var data = await _dataService.GetDataAsync();
    return Ok(data);
}
```

## Naming Conventions
1. Use `I` prefix for interfaces (e.g., `IService`).
2. Use `Async` suffix for asynchronous methods (e.g., `GetDataAsync`).
3. Use singular names for classes (e.g., `ProductController` instead of `ProductsController`).

## Test Generation and Creation
1. Use **xUnit** as the testing framework.
2. Use **Moq** for mocking dependencies.
3. Write unit tests for all public methods and ensure high code coverage.
4. Follow the **Arrange-Act-Assert** pattern in tests.
5. Name test methods descriptively using the format: `MethodName_StateUnderTest_ExpectedBehavior`.

Example:
```csharp
[Fact]
public async Task GetDataAsync_ValidRequest_ReturnsData()
{
    // Arrange
    var mockService = new Mock<IDataService>();
    mockService.Setup(s => s.GetDataAsync()).ReturnsAsync(new List<string> { "Item1", "Item2" });
    var controller = new MyController(mockService.Object);

    // Act
    var result = await controller.GetDataAsync();

    // Assert
    var okResult = Assert.IsType<OkObjectResult>(result);
    var data = Assert.IsType<List<string>>(okResult.Value);
    Assert.Equal(2, data.Count);
}
```

## Azure Functions and Cloud Development
1. Use **Azure SDKs** for interacting with Azure services.
2. Use **Configuration** and **Environment Variables** for sensitive data (e.g., connection strings).
3. Write idempotent and stateless Azure Functions.
4. Use **Durable Functions** for orchestrating workflows when needed.

Example:
```csharp
[FunctionName("MyFunction")]
public async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
    ILogger log)
{
    log.LogInformation("C# HTTP trigger function processed a request.");
    string name = req.Query["name"];
    return new OkObjectResult($"Hello, {name}");
}
```

## Additional Practices
1. Use **FluentValidation** for input validation in ASP.NET Core projects.
2. Use **Swagger/OpenAPI** for documenting Web APIs.
3. Write integration tests for critical workflows.
4. Use **Application Insights** for advanced logging and telemetry in production environments.

## Code Reviews
1. Ensure code adheres to these guidelines before merging.
2. Check for proper exception handling and logging.
3. Verify that all new code has corresponding unit tests.

## Documentation
1. Use XML comments for public methods and classes.
2. Provide clear and concise summaries for APIs and services.

## Security
1. Always validate user input to prevent injection attacks.
2. Use HTTPS for all communication.
3. Store secrets securely using **Azure Key Vault** or similar services.

## Performance
1. Use caching (e.g., **MemoryCache**, **DistributedCache**) for frequently accessed data.
2. Avoid unnecessary allocations and use `Span<T>` or `Memory<T>` for performance-critical code.

## Continuous Integration/Continuous Deployment (CI/CD)
1. Use GitHub Actions or Azure DevOps for CI/CD pipelines.
2. Run unit tests and integration tests as part of the CI pipeline.
3. Deploy to Azure using Infrastructure as Code (e.g., **Bicep**, **Terraform**, or **ARM templates**).

## Updates
1. Regularly update dependencies to the latest stable versions.
2. Monitor for breaking changes when upgrading to newer versions of .NET or libraries.