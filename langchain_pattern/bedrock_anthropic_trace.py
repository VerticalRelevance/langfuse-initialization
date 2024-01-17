import os
from langchain.llms import OpenAI
from langchain.chains import LLMChain
from langchain.chat_models import ChatAnthropic, ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langfuse.callback import CallbackHandler
from langchain_community.llms.bedrock import (
    Bedrock,
    BedrockBase,
)
import boto3
from langchain.chains import LLMChain

# Load API keys from environment variables
PUBLIC_KEY = os.getenv('LF_PUBLIC_KEY') # these are not sensative keys, 
SECRET_KEY = os.getenv('LF_PRIVATE_KEY') # these are not sensative keys
LANGFUSE_HOST = os.getenv('LF_HOST_URL') # Ex. "http://192.168.1.134:3000/"
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')

# Check if keys are set
if not all([PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST, OPENAI_API_KEY]):
    raise ValueError("API keys are not set in environment variables")

handler = CallbackHandler(PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST) # this is where Langfuse integration happens

prompt = ChatPromptTemplate.from_template(
    "Give me small report about {topic}"
)

model = Bedrock(
    credentials_profile_name='default', model_id="anthropic.claude-v2", verbose=True
)

output_parser = StrOutputParser()

chain = LLMChain(
    prompt=prompt,
    llm=model,
    output_parser=output_parser
)

# and run
out = chain.invoke(input="SRE & Resiliency in AWS", config={"callbacks":[handler]}) # Call to LangChain LangFuse Handler
print(out)