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
PUBLIC_KEY = "pk-lf-22847867-6b8f-4c5e-84c6-3d1370320f63" # these are not sensative keys
SECRET_KEY = "sk-lf-8c0c33e7-3008-4b16-bd51-8b0dedbe6c61" # these are not sensative keys
LANGFUSE_HOST = "http://192.168.1.134:3000/" # these are not sensative keys
OPENAI_API_KEY = os.getenv('WORDPRESS_PERSONAL_OPENAI_API')

# Check if keys are set
if not all([PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST, OPENAI_API_KEY]):
    raise ValueError("API keys are not set in environment variables")

handler = CallbackHandler(PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST)

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
out = chain.invoke(input="Artificial Intelligence", config={"callbacks":[handler]})
print(out)