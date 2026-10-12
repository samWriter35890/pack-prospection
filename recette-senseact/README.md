# Recette SenseAct

Outil interne de SenseAct. Il enregistre dans la table `Recette` d'une base NoCoDB ce qui s'est passé pendant un test d'une compétence : la phrase jouée, la réponse, les appels faits à la base et les enregistrements écrits, relus dans la base.

Il ne déclare aucun connecteur : il s'appuie sur celui du plugin testé. Il n'est jamais livré à un client.
