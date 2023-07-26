#r "Newtonsoft.Json"

using Newtonsoft.Json;
using Microsoft.AspNetCore.Mvc;

using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.AI.ChatCompletion;
using Microsoft.SemanticKernel.AI.ImageGeneration;

public static async Task<IActionResult> Run(HttpRequest request, ILogger logger)
{
  string requestBody = await new StreamReader(request.Body).ReadToEndAsync();
  dynamic requestData = JsonConvert.DeserializeObject(requestBody);

  dynamic chat = requestData.chat;
  string chatModelName = chat.modelName;
  string chatHistoryContext = chat.historyContext;
  string chatRequestMessage = chat.requestMessage;

  dynamic image = requestData.image;
  string imageDescription = image.description;
  int imageHeight = image.height;
  int imageWidth = image.width;

  string openAI_apiEndpoint = Environment.GetEnvironmentVariable("AzureOpenAI_ApiEndpoint");
  string openAI_apiKey = Environment.GetEnvironmentVariable("AzureOpenAI_ApiKey");

  KernelBuilder kernelBuilder = new KernelBuilder();
  kernelBuilder.WithAzureChatCompletionService(chatModelName, openAI_apiEndpoint, openAI_apiKey);
  kernelBuilder.WithAzureOpenAIImageGenerationService(openAI_apiEndpoint, openAI_apiKey);
  IKernel kernel = kernelBuilder.Build();

  Dictionary<string, string> functionResult = new Dictionary<string, string>();
  try
  {
    IChatCompletion chatGPT = kernel.GetService<IChatCompletion>();
    ChatHistory chatHistory = chatGPT.CreateNewChat(chatHistoryContext);
    chatHistory.AddUserMessage(chatRequestMessage);
    functionResult["chatResponse"] = await chatGPT.GenerateMessageAsync(chatHistory);

    if (imageDescription == "") {
      imageDescription = functionResult["chatResponse"];
    }

    IImageGeneration dallE = kernel.GetService<IImageGeneration>();
    functionResult["imageUrl"] = await dallE.GenerateImageAsync(imageDescription, imageWidth, imageHeight);
  }
  catch (Exception ex)
  {
    functionResult["exception"] = ex.ToString();
  }

  return new OkObjectResult(functionResult);
}
