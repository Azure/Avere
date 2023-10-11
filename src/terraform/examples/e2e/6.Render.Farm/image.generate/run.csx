#r "Newtonsoft.Json"

using Newtonsoft.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.AI.ChatCompletion;
using Microsoft.SemanticKernel.AI.ImageGeneration;

public static async Task<IActionResult> Run(HttpRequest request, ILogger logger)
{
  StreamReader requestStream = new StreamReader(request.Body);
  string requestBody = await requestStream.ReadToEndAsync();
  dynamic requestData = JsonConvert.DeserializeObject(requestBody);

  dynamic chat = requestData.chatDeployment;
  dynamic image = requestData.imageGeneration;

  string openAI_apiEndpoint = Environment.GetEnvironmentVariable("AzureOpenAI_ApiEndpoint");
  string openAI_apiKey = Environment.GetEnvironmentVariable("AzureOpenAI_ApiKey");

  KernelBuilder kernelBuilder = new KernelBuilder();
  kernelBuilder.WithAzureChatCompletionService((string) chat.modelName, openAI_apiEndpoint, openAI_apiKey);
  kernelBuilder.WithAzureOpenAIImageGenerationService(openAI_apiEndpoint, openAI_apiKey);
  IKernel kernel = kernelBuilder.Build();

  Dictionary<string, string> result = new Dictionary<string, string>();
  try {
    IChatCompletion chatService = kernel.GetService<IChatCompletion>();
    ChatHistory chatHistory = chatService.CreateNewChat((string) chat.historyContext);
    chatHistory.AddUserMessage((string) chat.requestMessage);
    result["chatResponse"] = await chatService.GenerateMessageAsync(chatHistory);

    string imageDescription = image.description;
    if (imageDescription == "") {
      imageDescription = result["chatResponse"];
    }

    IImageGeneration imageService = kernel.GetService<IImageGeneration>();
    result["imageUrl"] = await imageService.GenerateImageAsync(imageDescription, (int) image.width, (int) image.height);
  } catch (Exception ex) {
    result["exception"] = ex.ToString();
  }

  return new OkObjectResult(result);
}
