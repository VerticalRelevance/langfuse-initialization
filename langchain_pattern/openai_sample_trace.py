import os
from langchain_community.llms import OpenAI
from langchain.chains import LLMChain
from langchain_community.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langfuse.callback import CallbackHandler

# Load API keys from environment variables
PUBLIC_KEY = os.getenv('LF_PUBLIC_KEY') # these are not sensative keys, 
SECRET_KEY = os.getenv('LF_PRIVATE_KEY') # these are not sensative keys
LANGFUSE_HOST = os.getenv('LF_HOST_URL') # Ex. "http://192.168.1.134:3000/"
OPENAI_API_KEY = os.getenv('VR_OPENAI_API_KEY')

# Check if keys are set
if not all([PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST, OPENAI_API_KEY]):
    raise ValueError("API keys are not set in environment variables")

handler = CallbackHandler(PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST)

prompt = ChatPromptTemplate.from_template(
    "Give me small report about {topic}"
)
model = ChatOpenAI(
    model="gpt-4",
    openai_api_key=OPENAI_API_KEY
)  # swap Anthropic for OpenAI with `ChatOpenAI` and `openai_api_key`
output_parser = StrOutputParser()

chain = LLMChain(
    prompt=prompt,
    llm=model,
    output_parser=output_parser
)

# and run
out = chain.invoke(input="Artificial Intelligence", config={"callbacks":[handler]})
print(out)