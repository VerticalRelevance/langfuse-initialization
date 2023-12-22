import os
from langchain.chains import LLMChain
from langchain.chat_models import ChatAnthropic
from langchain.prompts import ChatPromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langfuse.callback import CallbackHandler
from langchain_community.llms.bedrock import (
    Bedrock,
    BedrockBase,
)

# Load API keys from environment variables
PUBLIC_KEY = os.getenv('LANGFUSE_PUBLIC_KEY')
SECRET_KEY = os.getenv('LANGFUSE_SECRET_KEY')
LANGFUSE_HOST =  os.getenv('LANGFUSE_HOST')

# Check if keys are set
if not all([PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST]):
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