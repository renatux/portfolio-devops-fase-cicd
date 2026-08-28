#Define o tipo de SO
FROM nginx:alpine
# Copia o site teste para o root do nginx
COPY website/ /usr/share/nginx/html/
# Expõe a porta 80
EXPOSE 80
# Comando padrão quando o container iniciar
CMD ["nginx", "-g", "daemon off;"]
